"""
backend/report_service.py
Generates comprehensive PDF reports covering all computed KPIs and charts,
for one or more selected periods (years, months, or quarters). Reuses the
exact same compute_kpis() logic as the live dashboard, so report numbers
always match what's shown on-screen for the same range.
"""
import io
import matplotlib
matplotlib.use("Agg")  # non-interactive backend, safe for server-side rendering
import matplotlib.pyplot as plt
import pandas as pd
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, Image as RLImage, PageBreak
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle

from app.services import firebase_service
from app.routes.kpi_routes import compute_kpis


def _period_to_date_range(period_type: str, period: str) -> tuple[str, str]:
    """
    Converts a period string into a (start_date, end_date) pair.
    period_type: "yearly" | "monthly" | "quarterly"
    period examples: "2025" | "2025-03" | "2025Q1"
    """
    if period_type == "yearly":
        year = int(period)
        return f"{year}-01-01", f"{year}-12-31"

    if period_type == "monthly":
        p = pd.Period(period, freq="M")
        return str(p.start_time.date()), str(p.end_time.date())

    if period_type == "quarterly":
        p = pd.Period(period, freq="Q")
        return str(p.start_time.date()), str(p.end_time.date())

    raise ValueError(f"Unknown period_type: {period_type}")


def _make_bar_chart_image(data: dict, title: str, color: str = "#D4A853") -> io.BytesIO:
    fig, ax = plt.subplots(figsize=(6, 3))
    keys = list(data.keys())
    values = list(data.values())
    ax.bar(keys, values, color=color)
    ax.set_title(title, fontsize=11)
    ax.set_ylabel("%")
    plt.xticks(rotation=20, ha="right", fontsize=8)
    plt.tight_layout()
    buf = io.BytesIO()
    plt.savefig(buf, format="png", dpi=150)
    plt.close(fig)
    buf.seek(0)
    return buf


def _make_line_chart_image(labels: list, values: list, title: str) -> io.BytesIO:
    fig, ax = plt.subplots(figsize=(6, 3))
    ax.plot(labels, values, color="#D4A853", marker="o", markersize=3, linewidth=1.5)
    ax.fill_between(range(len(labels)), values, alpha=0.1, color="#D4A853")
    ax.set_title(title, fontsize=11)
    ax.set_ylabel("LKR")
    step = max(1, len(labels) // 10)
    ax.set_xticks(range(0, len(labels), step))
    ax.set_xticklabels([labels[i] for i in range(0, len(labels), step)], rotation=45, ha="right", fontsize=7)
    plt.tight_layout()
    buf = io.BytesIO()
    plt.savefig(buf, format="png", dpi=150)
    plt.close(fig)
    buf.seek(0)
    return buf


def _build_period_section(story, styles, period_label: str, kpis: dict):
    story.append(Paragraph(period_label, styles["Heading2"]))
    story.append(Spacer(1, 0.3 * cm))

    if kpis.get("no_data_in_range"):
        story.append(Paragraph("No campaign data found for this period.", styles["Normal"]))
        story.append(Spacer(1, 0.5 * cm))
        return

    # ── KPI summary table ──────────────────────────────────
    rows = [["Metric", "Value"]]
    kpi_display = [
        ("Total Campaigns", kpis.get("total_campaigns")),
        ("Total Customers", kpis.get("total_customers")),
        ("Redemption Rate", f"{kpis['redemption_rate']}%" if kpis.get("redemption_rate") is not None else "-"),
        ("Revenue Uplift vs Control", f"{kpis['revenue_uplift_vs_control_pct']}%" if kpis.get("revenue_uplift_vs_control_pct") is not None else "-"),
        ("Best Offer Type", kpis.get("best_offer_type", "-")),
        ("Best Offer Redemption Rate", f"{kpis['best_offer_redemption_rate']}%" if kpis.get("best_offer_redemption_rate") is not None else "-"),
        ("Best Channel", kpis.get("best_channel", "-")),
        ("Best Channel CTR", f"{kpis['best_channel_ctr']}%" if kpis.get("best_channel_ctr") is not None else "-"),
        ("Total Revenue (Redeemed Campaigns)", f"LKR {kpis['total_revenue']:,.0f}" if kpis.get("total_revenue") is not None else "-"),
        ("Model Accuracy", f"{kpis['model_accuracy']}%" if kpis.get("model_accuracy") is not None else "-"),
    ]
    for label, value in kpi_display:
        rows.append([label, str(value)])

    table = Table(rows, colWidths=[9 * cm, 7 * cm])
    table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#1A2744")),
        ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
        ("FONTSIZE", (0, 0), (-1, -1), 9),
        ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#CCCCCC")),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#F5F5F5")]),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
    ]))
    story.append(table)
    story.append(Spacer(1, 0.5 * cm))

    # ── Charts ──────────────────────────────────────────────
    if kpis.get("offer_type_breakdown"):
        img_buf = _make_bar_chart_image(kpis["offer_type_breakdown"], "Redemption Rate by Offer Type")
        story.append(RLImage(img_buf, width=16 * cm, height=8 * cm))
        story.append(Spacer(1, 0.4 * cm))

    if kpis.get("channel_breakdown"):
        img_buf = _make_bar_chart_image(kpis["channel_breakdown"], "Click-Through Rate by Channel", color="#7AA6C2")
        story.append(RLImage(img_buf, width=16 * cm, height=8 * cm))
        story.append(Spacer(1, 0.4 * cm))

    revenue_data = kpis.get("revenue_over_time")
    if revenue_data and revenue_data.get("labels"):
        img_buf = _make_line_chart_image(revenue_data["labels"], revenue_data["values"], "Revenue from Redeemed Campaigns Over Time")
        story.append(RLImage(img_buf, width=16 * cm, height=8 * cm))

    story.append(Spacer(1, 0.8 * cm))


def generate_report_pdf(period_type: str, periods: list[str]) -> bytes:
    """
    Generates a single PDF covering ALL selected periods, one section per
    period, each with the full KPI table and every chart the dashboard
    shows for that range.
    """
    ca = firebase_service.load_latest_csv("campaigns")
    cu = firebase_service.load_latest_csv("customers")

    if ca is None:
        raise ValueError("No campaign data found.")

    buf = io.BytesIO()
    doc = SimpleDocTemplate(buf, pagesize=A4, topMargin=2 * cm, bottomMargin=2 * cm)
    styles = getSampleStyleSheet()
    styles.add(ParagraphStyle(name="ReportTitle", fontSize=18, spaceAfter=12, textColor=colors.HexColor("#1A2744")))

    story = []
    story.append(Paragraph("SkyHigh Marketing Intelligence Report", styles["ReportTitle"]))
    story.append(Paragraph(f"Period type: {period_type.capitalize()}", styles["Normal"]))
    story.append(Paragraph(f"Periods included: {', '.join(periods)}", styles["Normal"]))
    story.append(Spacer(1, 0.8 * cm))

    for i, period in enumerate(periods):
        start_date, end_date = _period_to_date_range(period_type, period)
        kpis = compute_kpis(ca, cu, start_date=start_date, end_date=end_date)
        _build_period_section(story, styles, f"{period_type.capitalize()}: {period}", kpis)
        if i < len(periods) - 1:
            story.append(PageBreak())

    doc.build(story)
    buf.seek(0)
    return buf.getvalue()

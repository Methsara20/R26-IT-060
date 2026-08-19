import streamlit as st
import pandas as pd
import numpy as np
import pickle
import json
import os
import matplotlib.pyplot as plt
import matplotlib
matplotlib.use('Agg')
from shared.helpers import get_xai_reasoning

MODEL_PATH   = "model/model.pkl"
COLUMNS_PATH = "model/columns.json"

def load_model():
    if not os.path.exists(MODEL_PATH) or not os.path.exists(COLUMNS_PATH):
        return None, None
    with open(MODEL_PATH, "rb") as f:
        model = pickle.load(f)
    with open(COLUMNS_PATH, "r") as f:
        meta = json.load(f)
    return model, meta

def encode_input(input_dict, meta):
    features = meta["features"]
    encoders = meta["encoders"]
    row = []
    errors = []
    for feat in features:
        val = str(input_dict.get(feat, ""))
        classes = encoders[feat]
        if val not in classes:
            errors.append(f"'{val}' not recognized for '{feat}'. Valid: {classes}")
            row.append(0)
        else:
            row.append(classes.index(val))
    return np.array([row]), errors

def make_bar(labels, values, color, title, figsize=(6, 3)):
    fig, ax = plt.subplots(figsize=figsize)
    fig.patch.set_facecolor('#FFFFFF')
    ax.set_facecolor('#FFFFFF')
    bars = ax.barh(labels, values, color=color, edgecolor='none')
    ax.set_title(title, fontsize=11, fontweight='bold', color='#1A2744', pad=10)
    ax.tick_params(axis='y', labelsize=9, colors='#444444')
    ax.tick_params(axis='x', labelsize=8, colors='#888888')
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    ax.spines['left'].set_color('#DDDDDD')
    ax.spines['bottom'].set_color('#DDDDDD')
    for bar, val in zip(bars, values):
        ax.text(val + 0.005, bar.get_y() + bar.get_height()/2,
                f'{val*100:.1f}%', va='center', fontsize=9, color='#1A2744')
    ax.set_xlim(0, max(values) * 1.2)
    plt.tight_layout()
    return fig

def render(tab):
    with tab:
        st.markdown('<div class="sec-hdr">🤖 XGBoost Promotion Recommender</div>', unsafe_allow_html=True)

        model, meta = load_model()

        if model is None:
            st.markdown("""
            <div class="error-card">
                <div class="error-card-title">⚠️ Model not found</div>
                <div class="error-card-body">
                    The XGBoost model has not been trained yet.<br><br>
                    Run the training script first:<br>
                    <span class="col-pill">python train_model.py</span><br><br>
                    Make sure <b>skyhigh_campaigns.csv</b> and <b>skyhigh_customers.csv</b>
                    are in your project folder before running.
                </div>
            </div>""", unsafe_allow_html=True)
            return

        st.session_state.model_loaded = True

        # ── Model Info ────────────────────────────────────────
        st.markdown(f"""<div class="hub-card">
            <div class="hub-title">✅ Model Ready</div>
            <div class="hub-desc">
                Algorithm: <b>XGBoost Classifier</b><br>
                Predicts: <b>Best promotion type per customer segment</b><br>
                Accuracy: <b>{meta['accuracy']*100:.1f}%</b><br>
                Features: <b>{', '.join(meta['features'])}</b>
            </div>
        </div>""", unsafe_allow_html=True)

        st.markdown("<br>", unsafe_allow_html=True)

        # ── Single Prediction ─────────────────────────────────
        st.markdown('<div class="sec-hdr">Single Segment Prediction</div>', unsafe_allow_html=True)
        st.caption("Enter customer segment details to get a promotion recommendation.")

        r1, r2, r3, r4 = st.columns(4)
        with r1:
            age_opts = meta["encoders"]["age_group"]
            age_group = st.selectbox("Age Group", age_opts, key="rec_age")
        with r2:
            gen_opts = meta["encoders"]["gender"]
            gender = st.selectbox("Gender", gen_opts, key="rec_gender")
        with r3:
            tier_opts = meta["encoders"]["loyalty_tier"]
            loyalty_tier = st.selectbox("Loyalty Tier", tier_opts, key="rec_tier")
        with r4:
            ch_opts = meta["encoders"]["channel"]
            channel = st.selectbox("Channel", ch_opts, key="rec_channel")

        if st.button("🎯 Get Recommendation", use_container_width=True):
            input_dict = {
                "age_group":    age_group,
                "gender":       gender,
                "loyalty_tier": loyalty_tier,
                "channel":      channel,
            }
            X_input, errors = encode_input(input_dict, meta)

            if errors:
                for e in errors:
                    st.warning(e)
            else:
                probs      = model.predict_proba(X_input)[0]
                pred_idx   = np.argmax(probs)
                pred_offer = meta["offer_types"][pred_idx]
                pred_prob  = probs[pred_idx]

                # Sort by probability
                sorted_idx   = np.argsort(probs)[::-1]
                sorted_offers = [meta["offer_types"][i] for i in sorted_idx]
                sorted_probs  = [probs[i] for i in sorted_idx]

                st.markdown("<br>", unsafe_allow_html=True)

                # Top recommendation
                st.markdown(f"""
                <div style="background:#1A2744;border-radius:12px;padding:20px 24px;margin-bottom:16px;border:2px solid #D4A853">
                    <div style="color:#C4A882;font-size:12px;letter-spacing:1px;text-transform:uppercase">
                        Recommended Promotion for {gender} | {age_group} | {loyalty_tier} via {channel}
                    </div>
                    <div style="color:#D4A853;font-size:2rem;font-weight:700;margin:8px 0">{pred_offer}</div>
                    <div style="color:white;font-size:13px">
                        Predicted redemption probability: <b style="color:#D4A853">{pred_prob*100:.1f}%</b>
                    </div>
                </div>""", unsafe_allow_html=True)

                # All offer probabilities
                c1, c2 = st.columns([1.5, 1])
                with c1:
                    st.pyplot(make_bar(
                        sorted_offers, sorted_probs,
                        ["#D4A853" if o == pred_offer else "#1A2744" for o in sorted_offers],
                        "Redemption Probability by Offer Type"
                    ))
                with c2:
                    st.markdown("**📋 All Offer Scores**")
                    for offer, prob in zip(sorted_offers, sorted_probs):
                        bar_w = int(prob * 100)
                        star  = " ⭐" if offer == pred_offer else ""
                        st.markdown(f"""
                        <div style="margin-bottom:8px">
                            <div style="font-size:12px;color:#1A2744;font-weight:{'700' if offer == pred_offer else '400'}">{offer}{star}</div>
                            <div style="background:#EDE5D0;border-radius:4px;height:8px;margin-top:3px">
                                <div style="background:{'#D4A853' if offer == pred_offer else '#1A2744'};width:{bar_w}%;height:8px;border-radius:4px"></div>
                            </div>
                            <div style="font-size:11px;color:#888">{prob*100:.1f}%</div>
                        </div>""", unsafe_allow_html=True)

                # XAI
                if st.button("🤖 Explain this recommendation", key="xai_rec"):
                    evidence = (f"For a {gender} customer aged {age_group} with {loyalty_tier} loyalty "
                                f"on {channel} channel, XGBoost predicts {pred_offer} with "
                                f"{pred_prob*100:.1f}% redemption probability.")
                    with st.spinner("Generating explanation..."):
                        reasoning = get_xai_reasoning(
                            f"{gender} {age_group} {loyalty_tier}", evidence, st.session_state.claude_key)
                    st.markdown(f"""<div class="xai-panel">
                        <div style="font-weight:700;color:#1A2744;margin-bottom:8px">🤖 Why this promotion?</div>
                        <div style="color:#444;font-size:13px;line-height:1.6">{reasoning}</div>
                    </div>""", unsafe_allow_html=True)

        # ── Batch Prediction ──────────────────────────────────
        st.markdown("<br>", unsafe_allow_html=True)
        st.markdown('<div class="sec-hdr">Batch Prediction — All Segments</div>', unsafe_allow_html=True)
        st.caption("Runs predictions across all age group + gender combinations automatically.")

        if st.button("🚀 Run Batch Predictions", use_container_width=True):
            age_groups   = meta["encoders"]["age_group"]
            genders      = meta["encoders"]["gender"]
            tiers        = meta["encoders"]["loyalty_tier"]
            channels     = meta["encoders"]["channel"]

            results = []
            for ag in age_groups:
                for gn in genders:
                    for ti in tiers[:2]:  # top 2 tiers to keep it concise
                        for ch in channels[:2]:  # top 2 channels
                            input_dict = {"age_group": ag, "gender": gn,
                                         "loyalty_tier": ti, "channel": ch}
                            X_in, _ = encode_input(input_dict, meta)
                            probs    = model.predict_proba(X_in)[0]
                            pred_idx = np.argmax(probs)
                            results.append({
                                "Age Group":        ag,
                                "Gender":           gn,
                                "Loyalty Tier":     ti,
                                "Channel":          ch,
                                "Recommended Offer":meta["offer_types"][pred_idx],
                                "Confidence":       f"{probs[pred_idx]*100:.1f}%"
                            })

            results_df = pd.DataFrame(results)
            st.success(f"✅ {len(results_df)} predictions generated!")
            st.dataframe(results_df, use_container_width=True, hide_index=True)

            # Download
            csv = results_df.to_csv(index=False)
            st.download_button(
                "⬇️ Download Recommendations CSV",
                csv,
                "promotion_recommendations.csv",
                "text/csv"
            )

        # ── Feature Importance ────────────────────────────────
        st.markdown("<br>", unsafe_allow_html=True)
        st.markdown('<div class="sec-hdr">Feature Importance</div>', unsafe_allow_html=True)
        fi = meta["feature_importance"]
        fig, ax = plt.subplots(figsize=(6, 3))
        fig.patch.set_facecolor('#FFFFFF')
        ax.set_facecolor('#FFFFFF')
        bars = ax.barh(list(fi.keys()), list(fi.values()), color="#1A2744", edgecolor='none')
        ax.set_title("Which features matter most for promotion prediction?",
                     fontsize=11, fontweight='bold', color='#1A2744', pad=10)
        ax.tick_params(axis='y', labelsize=9, colors='#444444')
        ax.tick_params(axis='x', labelsize=8, colors='#888888')
        ax.spines['top'].set_visible(False)
        ax.spines['right'].set_visible(False)
        for bar, val in zip(bars, fi.values()):
            ax.text(val + 0.005, bar.get_y() + bar.get_height()/2,
                    f'{val:.3f}', va='center', fontsize=9, color='#1A2744')
        plt.tight_layout()
        st.pyplot(fig)

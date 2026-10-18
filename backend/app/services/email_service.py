import os
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.image import MIMEImage
from dotenv import load_dotenv

load_dotenv()

GMAIL_ADDRESS = os.getenv("GMAIL_ADDRESS")
GMAIL_APP_PASSWORD = os.getenv("GMAIL_APP_PASSWORD")
GMAIL_SENDER_NAME = os.getenv("GMAIL_SENDER_NAME", "SkyHigh Marketing")

SMTP_SERVER = "smtp.gmail.com"
SMTP_PORT = 587


def send_poster_email(
    recipient_emails: list[str],
    subject: str,
    message_body: str,
    image_bytes: bytes = None,
    image_filename: str = "poster.png",
) -> dict:
    """
    Sends an email with an optional poster image attached to one or more
    recipients. Sends a separate email to each recipient (rather than one
    email with everyone in the To: field), so recipients don't see each
    other's addresses.
    Returns a dict with overall success status, plus per-recipient results.
    """
    if not GMAIL_ADDRESS or not GMAIL_APP_PASSWORD:
        return {"success": False, "error": "Email credentials not configured on the server."}

    if not recipient_emails:
        return {"success": False, "error": "At least one recipient email is required."}

    sent = []
    failed = []

    try:
        with smtplib.SMTP(SMTP_SERVER, SMTP_PORT) as server:
            server.starttls()
            server.login(GMAIL_ADDRESS, GMAIL_APP_PASSWORD)

            for recipient in recipient_emails:
                recipient = recipient.strip()
                if not recipient:
                    continue
                try:
                    msg = MIMEMultipart()
                    msg["From"] = f"{GMAIL_SENDER_NAME} <{GMAIL_ADDRESS}>"
                    msg["To"] = recipient
                    msg["Subject"] = subject
                    msg.attach(MIMEText(message_body, "plain"))

                    if image_bytes:
                        image = MIMEImage(image_bytes, name=image_filename)
                        msg.attach(image)

                    server.send_message(msg)
                    sent.append(recipient)
                except Exception as e:
                    failed.append({"email": recipient, "error": str(e)})

    except smtplib.SMTPAuthenticationError:
        return {"success": False, "error": "Authentication failed. Check the Gmail app password."}
    except Exception as e:
        return {"success": False, "error": f"Failed to connect to email server: {str(e)}"}

    if not sent:
        return {"success": False, "error": f"Failed to send to all recipients: {failed}"}

    message = f"Email sent to {len(sent)} recipient(s): {', '.join(sent)}"
    if failed:
        message += f". Failed for {len(failed)}: {', '.join(f['email'] for f in failed)}"

    return {"success": True, "message": message, "sent": sent, "failed": failed}
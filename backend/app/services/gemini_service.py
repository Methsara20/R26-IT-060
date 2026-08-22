# app/services/gemini_service.py

from google import genai
from google.genai import types

# Initialize the client
client = genai.Client(
    vertexai=True,
    project="divine-clone-495811-e4",
    location="us-central1"
)

def generate_try_on_image(
    human_image_path: str,
    cloth_image_path: str,
    output_path: str,
):
    # Call the virtual try-on model
    response = client.models.recontext_image(
        model="virtual-try-on-001",
        source=types.RecontextImageSource(
            person_image=types.Image.from_file(location=human_image_path),
            product_images=[
                types.ProductImage(
                    product_image=types.Image.from_file(location=cloth_image_path)
                )
            ],
        ),
        config=types.RecontextImageConfig(
            output_mime_type="image/png",
            number_of_images=1,
            safety_filter_level="BLOCK_LOW_AND_ABOVE",
        )
    )

    # Save generated image
    for generated_image in response.generated_images:
        generated_image.image.save(output_path)
        break

    return output_path
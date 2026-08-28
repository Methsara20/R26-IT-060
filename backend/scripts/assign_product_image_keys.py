"""
Assign representative GitHub Pages images to Firestore products.

Run from the ai-service project root:

    python -m scripts.assign_product_image_keys

Start with TEST_MODE = True.
After verifying the test documents, change it to False.
"""

from typing import Any

from app.config.settings import PRODUCT_IMAGE_BASE_URL
from scripts.firestore_helper import db


PRODUCTS_COLLECTION = "products"
BATCH_SIZE = 450

# Start safely with test mode.
TEST_MODE = False

# Add any product IDs you want to test first.
TEST_PRODUCT_IDS = {
    "P0001",
    "P0005",
}


# ==========================================================
# IMAGE MAPPING
# ==========================================================

IMAGE_MAPPING = {
    # Kids
    ("kids", "boys wear"): "kids_boys",
    ("kids", "girls wear"): "kids_girls",
    ("kids", "kids t-shirts"): "kids_tshirt",
    ("kids", "kids shorts"): "kids_shorts",
    ("kids", "t-shirts"): "kids_tshirt",
    ("kids", "shorts"): "kids_shorts",
    ("kids", "jackets"): "kids_boys",
    ("kids", "jeans"): "kids_boys",
    ("kids", "shirts"): "kids_boys",
    ("kids", "dresses"): "kids_girls",
    ("kids", "skirts"): "kids_girls",
    ("kids", "tops"): "kids_girls",
    ("kids", "trousers"): "kids_boys",

    # Men
    ("men", "t-shirts"): "men_tshirt",
    ("men", "polo shirts"): "men_polo",
    ("men", "shirts"): "men_shirt",
    ("men", "jackets"): "men_jacket",
    ("men", "jeans"): "men_jeans",
    ("men", "trousers"): "men_trousers",
    ("men", "shorts"): "men_trousers",
    ("men", "tops"): "men_tshirt",

    # Women
    ("women", "dresses"): "women_dress",
    ("women", "tops"): "women_top",
    ("women", "skirts"): "women_skirt",
    ("women", "jeans"): "women_jeans",
    ("women", "shirts"): "women_shirt",
    ("women", "t-shirts"): "women_top",
    ("women", "jackets"): "women_jacket",
    ("women", "trousers"): "women_jeans",
    ("women", "shorts"): "women_skirt",
}


GENDER_FALLBACKS = {
    "kids": "kids_tshirt",
    "men": "men_tshirt",
    "male": "men_tshirt",
    "women": "women_top",
    "female": "women_top",
}


CATEGORY_FALLBACKS = {
    "accessories": "accessories",
    "footwear": "footwear",
    "kids": "kids_tshirt",
    "men": "men_tshirt",
    "women": "women_top",
}


# ==========================================================
# HELPERS
# ==========================================================

def normalize(value: Any) -> str:
    if value is None:
        return ""

    return " ".join(
        str(value)
        .strip()
        .lower()
        .replace("_", " ")
        .replace("-", " ")
        .split()
    )


def build_image_url(image_key: str) -> str:
    base_url = PRODUCT_IMAGE_BASE_URL.rstrip("/")
    return f"{base_url}/{image_key}.jpg"


def infer_image_key(product: dict) -> str:
    """
    Select an image using:
    1. category
    2. gender
    3. subcategory
    4. product-name keywords
    """

    category = normalize(
        product.get("category")
    )

    gender = normalize(
        product.get("gender")
    )

    subcategory = normalize(
        product.get("subcategory")
    )

    product_name = normalize(
        product.get("product_name")
    )

    # Direct category types
    if category == "accessories":
        return "accessories"

    if category == "footwear":
        return "footwear"

    # Some datasets may store these values
    # in subcategory instead of category.
    if subcategory == "accessories":
        return "accessories"

    if subcategory == "footwear":
        return "footwear"

    # Exact gender + subcategory match.
    exact_key = (
        gender,
        subcategory,
    )

    if exact_key in IMAGE_MAPPING:
        return IMAGE_MAPPING[exact_key]

    # Try category as the demographic field.
    category_key = (
        category,
        subcategory,
    )

    if category_key in IMAGE_MAPPING:
        return IMAGE_MAPPING[category_key]

    # Product-name keyword fallback.
    if "accessor" in product_name:
        return "accessories"

    if any(
        keyword in product_name
        for keyword in [
            "shoe",
            "sneaker",
            "footwear",
        ]
    ):
        return "footwear"

    if gender in GENDER_FALLBACKS:
        return GENDER_FALLBACKS[gender]

    if category in CATEGORY_FALLBACKS:
        return CATEGORY_FALLBACKS[category]

    # Safe final fallback.
    return "accessories"


# ==========================================================
# BULK UPDATE
# ==========================================================

def assign_product_image_keys() -> None:
    documents = list(
        db.collection(
            PRODUCTS_COLLECTION
        ).stream()
    )

    if not documents:
        print("No products found in Firestore.")
        return

    print(f"Products found: {len(documents)}")
    print(f"Test mode: {TEST_MODE}")

    batch = db.batch()
    batch_count = 0
    total_updated = 0
    total_skipped = 0

    image_usage: dict[str, int] = {}

    for document in documents:
        product = document.to_dict()

        product_id = str(
            product.get(
                "product_id",
                document.id,
            )
        )

        if (
            TEST_MODE
            and product_id not in TEST_PRODUCT_IDS
        ):
            total_skipped += 1
            continue

        image_key = infer_image_key(product)
        image_url = build_image_url(image_key)

        batch.update(
            document.reference,
            {
                "image_key": image_key,
                "image_url": image_url,
                "image_type": "REPRESENTATIVE",
                "image_source": "GITHUB_PAGES",
            },
        )

        image_usage[image_key] = (
            image_usage.get(image_key, 0) + 1
        )

        batch_count += 1
        total_updated += 1

        print(
            f"{product_id}: "
            f"{product.get('gender')} / "
            f"{product.get('subcategory')} "
            f"→ {image_key}"
        )

        if batch_count >= BATCH_SIZE:
            batch.commit()
            print(
                f"Committed {total_updated} products..."
            )

            batch = db.batch()
            batch_count = 0

    if batch_count > 0:
        batch.commit()

    print("-" * 60)
    print(f"Updated: {total_updated}")
    print(f"Skipped: {total_skipped}")
    print("-" * 60)

    print("Image usage summary:")

    for image_key, count in sorted(
        image_usage.items()
    ):
        print(f"{image_key}: {count}")


if __name__ == "__main__":
    assign_product_image_keys()
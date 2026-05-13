def get_size(height: float, weight: float) -> str:
    if weight < 55:
        return "S"
    elif weight < 70:
        return "M"
    elif weight < 85:
        return "L"
    return "XL"
def get_size(height: float, weight: float) -> str:
    # Size score based on height (cm)
    if height < 165:
        h_score = 1  # S
    elif height < 175:
        h_score = 2  # M
    elif height < 185:
        h_score = 3  # L
    else:
        h_score = 4  # XL

    # Size score based on weight (kg)
    if weight < 60:
        w_score = 1  # S
    elif weight < 75:
        w_score = 2  # M
    elif weight < 90:
        w_score = 3  # L
    else:
        w_score = 4  # XL
        
    # Average the scores (round half up)
    avg_score = int((h_score + w_score) / 2 + 0.5)
    
    if avg_score <= 1:
        return "S"
    elif avg_score == 2:
        return "M"
    elif avg_score == 3:
        return "L"
    else:
        return "XL"
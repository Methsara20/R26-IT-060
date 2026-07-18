import csv
import random

def generate_synthetic_data(num_samples: int, output_filename: str):
    """
    Generates a synthetic dataset for training a Machine Learning model 
    to classify customer behavior as 'Browsing' or 'Transiting'.
    """
    headers = [
        "distance_moved_meters", 
        "time_elapsed_seconds", 
        "velocity_mps", 
        "direction_change_degrees", 
        "zone_dwell_time_seconds", 
        "intent_class"
    ]
    
    with open(output_filename, mode='w', newline='') as file:
        writer = csv.writer(file)
        writer.writerow(headers)
        
        for _ in range(num_samples):
            # Randomly decide if this sample is a Browser or a Transiter
            is_browsing = random.choice([True, False])
            
            time_elapsed = 10.0 # Assuming our heartbeat is exactly 10 seconds
            
            if is_browsing:
                # Browsers move slowly, turn a lot, and stay in zones longer
                velocity = round(random.uniform(0.0, 0.45), 2)
                direction_change = round(random.uniform(30.0, 180.0), 1)
                zone_dwell_time = round(random.uniform(40.0, 300.0), 1)
                intent_class = "Browsing"
            else:
                # Transiters move faster, walk in straight lines, and leave zones quickly
                velocity = round(random.uniform(0.6, 1.8), 2)
                direction_change = round(random.uniform(0.0, 15.0), 1)
                zone_dwell_time = round(random.uniform(10.0, 35.0), 1)
                intent_class = "Transiting"
                
            # Distance is derived from velocity and time
            distance_moved = round(velocity * time_elapsed, 2)
            
            # Write row to CSV
            writer.writerow([
                distance_moved,
                time_elapsed,
                velocity,
                direction_change,
                zone_dwell_time,
                intent_class
            ])
            
    print(f"✅ Successfully generated {num_samples} samples and saved to {output_filename}")

if __name__ == "__main__":
    generate_synthetic_data(num_samples=1000, output_filename="customer_tracking_dataset.csv")

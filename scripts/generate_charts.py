import pandas as pd
import matplotlib.pyplot as plt
import os
from datetime import datetime

print("📊 Starting joke analysis...")

# Create charts directory if it doesn't exist
os.makedirs('charts', exist_ok=True)

try:
    # Read your joke data from CSV
    df = pd.read_csv('history.csv')
    print(f"✅ Loaded {len(df)} jokes from CSV")
    
    # Convert timestamp to datetime
    df['timestamp'] = pd.to_datetime(df['timestamp'])
    df['date'] = df['timestamp'].dt.date
    df['hour'] = df['timestamp'].dt.hour
    
    # 1. Jokes per day chart
    jokes_per_day = df.groupby('date').size()
    
    plt.figure(figsize=(12, 6))
    jokes_per_day.plot(kind='bar', color='skyblue')
    plt.title('📈 Jokes Collected Per Day')
    plt.xlabel('Date')
    plt.ylabel('Number of Jokes')
    plt.xticks(rotation=45)
    plt.tight_layout()
    plt.savefig('charts/jokes_per_day.png')
    plt.close()
    print("✅ Created jokes_per_day.png")
    
    # 2. Joke source distribution
    source_counts = df['source'].value_counts()
    
    plt.figure(figsize=(10, 6))
    source_counts.plot(kind='pie', autopct='%1.1f%%', startangle=90)
    plt.title('🎯 Joke Sources Distribution')
    plt.ylabel('')  # Hide y-label for pie chart
    plt.tight_layout()
    plt.savefig('charts/joke_sources.png')
    plt.close()
    print("✅ Created joke_sources.png")
    
    # 3. Activity by hour
    hour_counts = df['hour'].value_counts().sort_index()
    
    plt.figure(figsize=(10, 6))
    hour_counts.plot(kind='bar', color='lightcoral')
    plt.title('🕐 Joke Collection Activity by Hour')
    plt.xlabel('Hour of Day')
    plt.ylabel('Number of Jokes')
    plt.tight_layout()
    plt.savefig('charts/activity_by_hour.png')
    plt.close()
    print("✅ Created activity_by_hour.png")
    
    # 4. Create a comprehensive stats file
    stats = f"""# 🎭 Joke Collection Statistics

Last updated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

## 📊 Summary
- **Total Jokes Collected**: {len(df)}
- **Collection Started**: {df['date'].min()}
- **Most Active Day**: {jokes_per_day.idxmax()} ({jokes_per_day.max()} jokes)
- **Most Popular Source**: {source_counts.index[0]} ({source_counts.iloc[0]} jokes)

## 📈 Charts
![Jokes Per Day](charts/jokes_per_day.png)
![Joke Sources](charts/joke_sources.png)  
![Activity by Hour](charts/activity_by_hour.png)

## 🔍 Source Breakdown
{source_counts.to_string()}

## ⏰ Peak Hours
{hour_counts.to_string()}
"""
    
    with open('JOKE_STATS.md', 'w') as f:
        f.write(stats)
    
    print("✅ Created JOKE_STATS.md")
    print("🎉 All charts generated successfully!")
    
except Exception as e:
    print(f"❌ Error generating charts: {e}")
    import traceback
    traceback.print_exc()
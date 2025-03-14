import requests
import json
import os
import re
import time
import random
from datetime import datetime
from bs4 import BeautifulSoup
import concurrent.futures
from tqdm import tqdm

# Configuration
OUTPUT_PATH = "TalentData.lua"
MAX_WORKERS = 10  # Adjust based on your system and to avoid rate limiting
RATE_LIMIT_DELAY = (0.5, 1.5)  # Random delay range in seconds

# Boss mappings (WoW encounter ID to Archon.gg URL slug)
BOSS_MAPPINGS = {
    3009: "vexie",
    3010: "cauldron-of-carnage", 
    3011: "rik-reverb",
    3012: "stix-bunkjunker",
    3013: "lockenstock",
    3014: "one-armed-bandit",
    3015: "mugzee",
    3016: "gallywix"
}

# Reverse mapping to look up boss ID by slug
BOSS_SLUG_TO_ID = {slug: boss_id for boss_id, slug in BOSS_MAPPINGS.items()}

# Boss display names for the addon
BOSS_NAMES = {
    3009: "Vexie and the Geargrinders",
    3010: "Cauldron of Carnage", 
    3011: "Rik Reverb",
    3012: "Stix Bunkjunker",
    3013: "Lockenstock",
    3014: "One-Armed Bandit",
    3015: "Mug'Zee, Heads of Security",
    3016: "Chrome King Gallywix"
}

# Class and spec information
CLASS_SPECS = {
    "DEATHKNIGHT": {1: "blood", 2: "frost", 3: "unholy"},
    "DEMONHUNTER": {1: "havoc", 2: "vengeance"},
    "DRUID": {1: "balance", 2: "feral", 3: "guardian", 4: "restoration"},
    "EVOKER": {1: "devastation", 2: "preservation", 3: "augmentation"},
    "HUNTER": {1: "beast-mastery", 2: "marksmanship", 3: "survival"},
    "MAGE": {1: "arcane", 2: "fire", 3: "frost"},
    "MONK": {1: "brewmaster", 2: "mistweaver", 3: "windwalker"},
    "PALADIN": {1: "holy", 2: "protection", 3: "retribution"},
    "PRIEST": {1: "discipline", 2: "holy", 3: "shadow"},
    "ROGUE": {1: "assassination", 2: "outlaw", 3: "subtlety"},
    "SHAMAN": {1: "elemental", 2: "enhancement", 3: "restoration"},
    "WARLOCK": {1: "affliction", 2: "demonology", 3: "destruction"},
    "WARRIOR": {1: "arms", 2: "fury", 3: "protection"}
}

# Reverse mapping from slug to spec ID
CLASS_SPEC_SLUG_TO_ID = {}
for class_name, specs in CLASS_SPECS.items():
    for spec_id, spec_slug in specs.items():
        if class_name not in CLASS_SPEC_SLUG_TO_ID:
            CLASS_SPEC_SLUG_TO_ID[class_name] = {}
        CLASS_SPEC_SLUG_TO_ID[class_name][spec_slug] = spec_id

# Difficulty mappings
DIFFICULTIES = ["normal", "heroic", "mythic"]

# Headers to mimic a browser
HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xml",
    "Accept-Language": "en-US,en;q=0.9"
}

def extract_talent_code_from_page(html_content):
    """Extract talent code from Archon.gg's export links"""
    # Create a BeautifulSoup object
    soup = BeautifulSoup(html_content, 'html.parser')
    
    # Look for the export link with wowhead talent calc URL
    export_links = soup.select('a[href*="wowhead.com/talent-calc/blizzard/"]')
    
    if export_links:
        # Extract the URL
        talent_url = export_links[0].get('href', '')
        
        # Extract the talent code from the URL
        match = re.search(r'talent-calc/blizzard/([A-Za-z0-9_-]+)', talent_url)
        if match:
            return match.group(1)
    
    # If we didn't find the export link, try looking for a copy button with the talent-tree class
    copy_buttons = soup.select('.talent-tree_interactions-export_copy-button')
    if copy_buttons:
        # The talent code might be in a nearby element or as a data attribute
        parent = copy_buttons[0].parent
        export_links = parent.select('a[href*="wowhead.com/talent-calc/blizzard/"]')
        if export_links:
            talent_url = export_links[0].get('href', '')
            match = re.search(r'talent-calc/blizzard/([A-Za-z0-9_-]+)', talent_url)
            if match:
                return match.group(1)
    
    # If still not found, try one more approach: look for external links with talent-calc in URL
    external_links = soup.select('a.talent-tree_interactions-export_external-link')
    if external_links:
        for link in external_links:
            href = link.get('href', '')
            if 'wowhead.com/talent-calc/blizzard/' in href:
                match = re.search(r'talent-calc/blizzard/([A-Za-z0-9_-]+)', href)
                if match:
                    return match.group(1)
    
    return None

def format_class_name(class_name):
    """Format class name for URL (lowercase and hyphenated if needed)"""
    formatted = class_name.lower()
    if formatted == "deathknight":
        return "death-knight"
    elif formatted == "demonhunter":
        return "demon-hunter"
    return formatted

def fetch_build(combo):
    """Fetch a single build based on the combo parameters"""
    url = f"https://www.archon.gg/wow/builds/{combo['spec_slug']}/{combo['formatted_class']}/raid/talents/{combo['difficulty']}/{combo['boss_slug']}"
    
    try:
        response = requests.get(url, headers=HEADERS, timeout=10)
        
        # Skip if page doesn't exist
        if response.status_code == 404:
            return None
            
        response.raise_for_status()
        
        # Extract talent code
        talent_code = extract_talent_code_from_page(response.text)
        
        if talent_code:
            # Return the talent information
            return {
                "boss_id": combo['boss_id'],
                "class_name": combo['class_name'],
                "spec_id": combo['spec_id'],
                "data": {
                    "title": f"{combo['difficulty'].capitalize()} {BOSS_NAMES.get(combo['boss_id'], combo['boss_slug'].capitalize())}",
                    "talents": talent_code,
                    "popularity": "N/A",
                    "source": f"Archon.gg ({combo['difficulty'].capitalize()})"
                }
            }
    
    except requests.exceptions.RequestException:
        pass
        
    # Be polite to the server - use a variable delay to avoid being blocked
    delay = RATE_LIMIT_DELAY[0] + ((RATE_LIMIT_DELAY[1] - RATE_LIMIT_DELAY[0]) * random.random())
    time.sleep(delay)
    
    return None

def parallel_scrape():
    """Scrape talent data in parallel"""
    talent_data = {}
    
    # Generate all combinations to try
    combinations = []
    
    # Add all class/spec combinations
    for class_name, specs in CLASS_SPECS.items():
        formatted_class = format_class_name(class_name)
        for spec_id, spec_slug in specs.items():
            # For each boss and difficulty
            for boss_id, boss_slug in BOSS_MAPPINGS.items():
                for difficulty in DIFFICULTIES:
                    combinations.append({
                        "class_name": class_name,
                        "formatted_class": formatted_class,
                        "spec_id": spec_id,
                        "spec_slug": spec_slug,
                        "boss_id": boss_id,
                        "boss_slug": boss_slug,
                        "difficulty": difficulty
                    })
    
    total_builds = len(combinations)
    print(f"Attempting to scrape {total_builds} talent builds in parallel...")
    
    # Use a ThreadPoolExecutor to run the scraping in parallel
    with concurrent.futures.ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        # Map the fetch_build function to combinations with progress tracking
        results = list(tqdm(
            executor.map(fetch_build, combinations),
            total=total_builds,
            desc="Scraping talent builds",
            unit="build"
        ))
    
    # Process results
    successful_scrapes = 0
    for result in results:
        if result:
            # Extract data
            boss_id = result['boss_id']
            class_name = result['class_name']
            spec_id = result['spec_id']
            spec_data = result['data']
            
            # Initialize the data structure if needed
            if boss_id not in talent_data:
                talent_data[boss_id] = {}
            if class_name not in talent_data[boss_id]:
                talent_data[boss_id][class_name] = {}
            
            # Store the talent information
            talent_data[boss_id][class_name][spec_id] = spec_data
            successful_scrapes += 1
    
    print(f"Scraping complete! Successfully scraped {successful_scrapes} out of {total_builds} attempted combinations")
    return talent_data

def generate_lua_file(talent_data, output_path):
    """Generate a Lua file with the talent data for the addon"""
    # Check if output path has a directory component
    output_dir = os.path.dirname(output_path)
    if output_dir:
        # Create directory if it doesn't exist
        os.makedirs(output_dir, exist_ok=True)
    
    with open(output_path, "w") as f:
        # Write header
        f.write("-- TalentScraper data file\n")
        f.write(f"-- Generated on {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("-- DO NOT EDIT THIS FILE MANUALLY\n\n")
        
        # Create the main table
        f.write("if not TalentScraper then return end\n\n")
        f.write("TalentScraper.TalentData = {\n")
        
        # Check if we have any data to write
        has_data = False
        
        # Write boss data
        for boss_id, boss_data in talent_data.items():
            boss_id_str = str(boss_id)
            boss_name = BOSS_NAMES.get(int(boss_id), "Unknown Boss")
            f.write(f"    [{boss_id_str}] = {{ -- {boss_name}\n")
            
            # Write class data
            for class_name, class_data in boss_data.items():
                f.write(f'        ["{class_name}"] = {{\n')
                
                # Write spec data
                for spec_id, spec_data in class_data.items():
                    spec_id_str = str(spec_id)
                    
                    # Get the spec name for the comment
                    spec_name = CLASS_SPECS.get(class_name, {}).get(int(spec_id), "Unknown")
                    spec_display = spec_name.replace("-", " ").title()
                    
                    f.write(f"            [{spec_id_str}] = {{ -- {spec_display}\n")
                    f.write(f'                title = "{spec_data["title"]}",\n')
                    f.write(f'                talents = "{spec_data["talents"]}",\n')
                    f.write(f'                popularity = "{spec_data["popularity"]}",\n')
                    f.write(f'                source = "{spec_data["source"]}"\n')
                    f.write("            },\n")
                    
                    has_data = True
                
                f.write("        },\n")
            
            f.write("    },\n")
        
        # Close the main table
        f.write("}\n")
        
        # Notify if no data was written
        if not has_data:
            print("WARNING: No talent data was written to the Lua file!")

def main():
    print("Archon.gg Parallel Talent Scraper")
    print("--------------------------------")
    
    # Perform parallel scraping
    talent_data = parallel_scrape()
    
    # Generate Lua file
    print("Generating Lua file...")
    generate_lua_file(talent_data, OUTPUT_PATH)
    
    # Count how many builds we found
    total_builds = sum(
        sum(
            len(class_data) 
            for class_data in boss_data.values()
        ) 
        for boss_data in talent_data.values()
    )
    
    print(f"Done! Found {total_builds} talent builds across all bosses, difficulties, and specs.")
    print(f"Talent data saved to {OUTPUT_PATH}")

if __name__ == "__main__":
    main()

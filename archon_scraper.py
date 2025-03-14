import requests
import json
import os
import re
import time
import random
from datetime import datetime
from bs4 import BeautifulSoup

# Configuration
OUTPUT_PATH = "TalentData.lua"

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

def get_available_builds():
    """Get a list of available builds from Archon.gg"""
    available_builds = []
    
    # For each class and spec, check which bosses and difficulties have data
    for class_name, specs in CLASS_SPECS.items():
        for spec_id, spec_slug in specs.items():
            # For Archon.gg, class name is lowercase and URL uses spec slug first
            main_url = f"https://www.archon.gg/wow/builds/{spec_slug}/{class_name.lower()}/raid/talents"
            
            print(f"Checking available builds for {class_name} {spec_slug}...")
            
            try:
                response = requests.get(main_url, headers=HEADERS)
                
                # If the page doesn't exist, continue to the next spec
                if response.status_code == 404:
                    print(f"No raid talent builds found for {class_name} {spec_slug}")
                    continue
                    
                response.raise_for_status()
                
                # Parse the HTML
                soup = BeautifulSoup(response.text, 'html.parser')
                
                # Look for links that match boss pages
                # In Archon.gg's structure, they usually have links to specific boss builds
                links = soup.find_all('a', href=True)
                
                # Check each link to see if it's a boss page
                for link in links:
                    href = link['href']
                    
                    # Look for links that match the pattern for boss talent builds
                    for difficulty in DIFFICULTIES:
                        for boss_slug in BOSS_MAPPINGS.values():
                            # Check if this is a link to a specific boss build
                            pattern = f"/wow/builds/{spec_slug}/{class_name.lower()}/raid/talents/{difficulty}/{boss_slug}"
                            if pattern in href:
                                boss_id = BOSS_SLUG_TO_ID[boss_slug]
                                available_builds.append({
                                    "class_name": class_name,
                                    "spec_id": spec_id,
                                    "spec_slug": spec_slug,
                                    "difficulty": difficulty,
                                    "boss_id": boss_id,
                                    "boss_slug": boss_slug,
                                    "url": f"https://www.archon.gg{href}"
                                })
                                print(f"Found build: {class_name} {spec_slug} - {difficulty} {boss_slug}")
                
                # If no specific boss links are found, check if there's a general recommended build
                if not any(build['class_name'] == class_name and build['spec_id'] == spec_id for build in available_builds):
                    # If there's talent data on this page, add it as a general build
                    if extract_talent_code_from_page(response.text):
                        # Use the first boss as a placeholder (typically Gallywix as it's often the main boss)
                        boss_slug = "gallywix"
                        boss_id = BOSS_SLUG_TO_ID[boss_slug]
                        available_builds.append({
                            "class_name": class_name,
                            "spec_id": spec_id,
                            "spec_slug": spec_slug,
                            "difficulty": "normal",  # Default to normal difficulty
                            "boss_id": boss_id,
                            "boss_slug": boss_slug,
                            "url": main_url
                        })
                        print(f"Found general build for {class_name} {spec_slug}")
            
            except requests.exceptions.RequestException as e:
                print(f"Error checking {main_url}: {e}")
            
            # Be polite to the server
            time.sleep(1)
    
    return available_builds

def scrape_talent_data():
    """Scrape talent data from Archon.gg for available builds"""
    talent_data = {}
    
    # First, get a list of available builds
    available_builds = get_available_builds()
    
    if not available_builds:
        print("No builds found to scrape!")
        # Try direct scraping for some common builds
        return try_direct_scraping()
    
    print(f"Found {len(available_builds)} available builds to scrape")
    
    # Now, scrape each available build
    for build in available_builds:
        class_name = build["class_name"]
        spec_id = build["spec_id"]
        difficulty = build["difficulty"]
        boss_id = build["boss_id"]
        boss_slug = build["boss_slug"]
        
        # Use the URL from the build if available, otherwise construct it
        url = build.get("url")
        if not url:
            url = f"https://www.archon.gg/wow/builds/{build['spec_slug']}/{class_name.lower()}/raid/talents/{difficulty}/{boss_slug}"
        
        print(f"Scraping {class_name} {spec_id} for {boss_slug} ({difficulty})...")
        
        try:
            response = requests.get(url, headers=HEADERS)
            response.raise_for_status()
            
            # Extract talent code using the new function
            talent_code = extract_talent_code_from_page(response.text)
            
            if talent_code:
                # Initialize the data structure if needed
                if boss_id not in talent_data:
                    talent_data[boss_id] = {}
                if class_name not in talent_data[boss_id]:
                    talent_data[boss_id][class_name] = {}
                
                # Store the talent information
                talent_data[boss_id][class_name][spec_id] = {
                    "title": f"{difficulty.capitalize()} {BOSS_NAMES.get(boss_id, boss_slug.capitalize())}",
                    "talents": talent_code,
                    "popularity": "N/A",
                    "source": f"Archon.gg ({difficulty.capitalize()})"
                }
                
                print(f"Found talent code: {talent_code[:30]}...")
            else:
                print(f"No talent code found on the page")
            
        except requests.exceptions.RequestException as e:
            print(f"Error scraping {url}: {e}")
        
        # Be polite to the server
        time.sleep(1)
    
    return talent_data

def try_direct_scraping():
    """Try direct scraping for all classes/specs/bosses and difficulties"""
    talent_data = {}
    
    # Update boss mappings with correct slugs
    updated_boss_mappings = {
        3009: "vexie",
        3010: "cauldron-of-carnage", 
        3011: "rik-reverb",
        3012: "stix-bunkjunker",
        3013: "lockenstock",
        3014: "one-armed-bandit",
        3015: "mugzee",
        3016: "gallywix"
    }
    
    # All difficulties to try
    difficulties = ["normal", "heroic", "mythic"]
    
    # Instead of trying all combinations, let's focus on known working patterns
    # based on the screenshot showing a Blood Death Knight page
    
    print("Attempting targeted scraping based on known working patterns...")
    
    # List of specific combinations to try
    targeted_combinations = []
    
    # Add all class/spec combinations
    for class_name, specs in CLASS_SPECS.items():
        for spec_id, spec_slug in specs.items():
            # The URL format appears to be different than we thought
            # For example: https://www.archon.gg/wow/builds/blood/death-knight/raid/talents/normal/vexie
            # Class name needs to be converted to lowercase and hyphenated if needed
            formatted_class = class_name.lower()
            if formatted_class == "deathknight":
                formatted_class = "death-knight"
            elif formatted_class == "demonhunter":
                formatted_class = "demon-hunter"
            
            # For each boss and difficulty
            for boss_id, boss_slug in updated_boss_mappings.items():
                for difficulty in difficulties:
                    targeted_combinations.append({
                        "class_name": class_name,
                        "formatted_class": formatted_class,
                        "spec_id": spec_id,
                        "spec_slug": spec_slug,
                        "boss_id": boss_id,
                        "boss_slug": boss_slug,
                        "difficulty": difficulty
                    })
    
    total_attempts = len(targeted_combinations)
    current_attempt = 0
    successful_scrapes = 0
    
    print(f"Will attempt {total_attempts} targeted combinations...")
    
    # Try each combination
    for combo in targeted_combinations:
        current_attempt += 1
        
        # Correctly format the URL based on the screenshot
        # Format: https://www.archon.gg/wow/builds/{spec_slug}/{formatted_class}/raid/talents/{difficulty}/{boss_slug}
        url = f"https://www.archon.gg/wow/builds/{combo['spec_slug']}/{combo['formatted_class']}/raid/talents/{combo['difficulty']}/{combo['boss_slug']}"
        
        # Display progress periodically
        if current_attempt % 10 == 0 or current_attempt == 1:
            progress = (current_attempt / total_attempts) * 100
            print(f"Progress: {progress:.1f}% ({current_attempt}/{total_attempts}), Success rate: {successful_scrapes}/{current_attempt}")
        
        print(f"Scraping {combo['class_name']} {combo['spec_slug']} - {combo['difficulty']} {combo['boss_slug']}...", end="", flush=True)
        
        try:
            response = requests.get(url, headers=HEADERS, timeout=10)
            
            # Skip if page doesn't exist
            if response.status_code == 404:
                print(" Not found")
                continue
                
            response.raise_for_status()
            
            # Extract talent code
            talent_code = extract_talent_code_from_page(response.text)
            
            if talent_code:
                # Initialize the data structure if needed
                boss_id = combo['boss_id']
                class_name = combo['class_name']
                spec_id = combo['spec_id']
                
                if boss_id not in talent_data:
                    talent_data[boss_id] = {}
                if class_name not in talent_data[boss_id]:
                    talent_data[boss_id][class_name] = {}
                
                # Store the talent information
                talent_data[boss_id][class_name][spec_id] = {
                    "title": f"{combo['difficulty'].capitalize()} {BOSS_NAMES.get(boss_id, combo['boss_slug'].capitalize())}",
                    "talents": talent_code,
                    "popularity": "N/A",
                    "source": f"Archon.gg ({combo['difficulty'].capitalize()})"
                }
                
                print(f" Success! Talent code: {talent_code[:20]}...")
                successful_scrapes += 1
            else:
                print(" No talent code found")
        
        except requests.exceptions.RequestException as e:
            print(f" Error: {str(e)[:50]}...")
        
        # Be polite to the server - use a variable delay to avoid being blocked
        delay = 1.0 + (0.5 * random.random())  # Between 1.0 and 1.5 seconds
        time.sleep(delay)
    
    print(f"Scraping complete! Successfully scraped {successful_scrapes} out of {total_attempts} attempted combinations")
    return talent_data

def generate_lua_file(talent_data, output_path):
    """Generate a Lua file with the talent data for the addon"""
    # Create directory if it doesn't exist
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    
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
    print("Archon.gg Talent Scraper")
    print("------------------------")
    
    # Skip the regular scraping approach and go directly to comprehensive direct scraping
    print("Performing comprehensive direct scraping for all class/spec/boss/difficulty combinations...")
    talent_data = try_direct_scraping()
    
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
import requests
from bs4 import BeautifulSoup
import re
import argparse

"""
Script to verify a single Archon.gg talent code.
Usage: python verify_archon_codes.py --class-name mage --spec fire --boss gallywix --difficulty normal
"""

def extract_talent_code(url):
    """Extract talent code from an Archon.gg URL"""
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
    }
    
    try:
        response = requests.get(url, headers=headers)
        response.raise_for_status()
        
        # Create a BeautifulSoup object
        soup = BeautifulSoup(response.text, 'html.parser')
        
        # Look for the export link with wowhead talent calc URL
        export_links = soup.select('a[href*="wowhead.com/talent-calc/blizzard/"]')
        
        if export_links:
            # Extract the URL
            talent_url = export_links[0].get('href', '')
            
            # Extract the talent code from the URL
            match = re.search(r'talent-calc/blizzard/([A-Za-z0-9_-]+)', talent_url)
            if match:
                return match.group(1)
        
        # Try other methods if the first fails
        copy_buttons = soup.select('.talent-tree_interactions-export_copy-button')
        if copy_buttons:
            parent = copy_buttons[0].parent
            export_links = parent.select('a[href*="wowhead.com/talent-calc/blizzard/"]')
            if export_links:
                talent_url = export_links[0].get('href', '')
                match = re.search(r'talent-calc/blizzard/([A-Za-z0-9_-]+)', talent_url)
                if match:
                    return match.group(1)
        
        # Last attempt
        external_links = soup.select('a.talent-tree_interactions-export_external-link')
        if external_links:
            for link in external_links:
                href = link.get('href', '')
                if 'wowhead.com/talent-calc/blizzard/' in href:
                    match = re.search(r'talent-calc/blizzard/([A-Za-z0-9_-]+)', href)
                    if match:
                        return match.group(1)
        
        return None
    
    except requests.exceptions.RequestException as e:
        print(f"Error: {e}")
        return None

def format_class_name(class_name):
    """Format class name for URL"""
    class_name = class_name.lower()
    if class_name == "deathknight":
        return "death-knight"
    elif class_name == "demonhunter":
        return "demon-hunter"
    return class_name

def main():
    parser = argparse.ArgumentParser(description='Verify Archon.gg talent code for a specific class, spec, boss, and difficulty')
    parser.add_argument('--class-name', required=True, help='Class name (e.g., mage, warrior)')
    parser.add_argument('--spec', required=True, help='Spec name (e.g., fire, arms)')
    parser.add_argument('--boss', required=True, help='Boss slug (e.g., gallywix, vexie)')
    parser.add_argument('--difficulty', default='normal', choices=['normal', 'heroic', 'mythic'], help='Difficulty')
    
    args = parser.parse_args()
    
    formatted_class = format_class_name(args.class_name)
    url = f"https://www.archon.gg/wow/builds/{args.spec}/{formatted_class}/raid/talents/{args.difficulty}/{args.boss}"
    
    print(f"Checking URL: {url}")
    talent_code = extract_talent_code(url)
    
    if talent_code:
        print(f"Found talent code: {talent_code}")
    else:
        print("No talent code found.")

if __name__ == "__main__":
    main()
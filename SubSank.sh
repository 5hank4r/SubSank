#!/bin/bash

# Function to print a color progress bar
print_progress() {
    local percentage="$1"
    local width=50  # Width of the progress bar
    local fill="$(printf "%-$((percentage / (100 / width)))s" "")"
    local empty="$(printf "%-$((width - (percentage / (100 / width))))s" "")"
    echo -e "\r[\033[1;32m$fill\033[0m$empty] $percentage%"
}

# Function to display tool status with color and formatting
Running() {
    local tool_name="$1"
    echo -e "\033[1;34m=== \033[1;37mRunning $tool_name Enumeration\033[1;34m ===\033[0m"
}

# Function to display the custom "subsank" banner in green color
display_banner() {
    echo -e "\033[1;32m"  # Set text color to green
    echo -e "
    _  _  _  _                   _                                  _  _  _  _                                  _               
   _(_)(_)(_)(_)_                (_)                               _(_)(_)(_)(_)_                               (_)              
  (_)          (_) _         _   (_) _  _  _                      (_)          (_)   _  _  _       _  _  _  _   (_)     _        
  (_)_  _  _  _   (_)       (_)  (_)(_)(_)(_)_                    (_)_  _  _  _     (_)(_)(_) _   (_)(_)(_)(_)_ (_)   _(_)       
    (_)(_)(_)(_)_ (_)       (_)  (_)        (_)                     (_)(_)(_)(_)_    _  _  _ (_)  (_)        (_)(_) _(_)         
   _           (_)(_)       (_)  (_)        (_)                    _           (_) _(_)(_)(_)(_)  (_)        (_)(_)(_)_          
  (_)_  _  _  _(_)(_)_  _  _(_)_ (_) _  _  _(_)                   (_)_  _  _  _(_)(_)_  _  _ (_)_ (_)        (_)(_)  (_)_        
    (_)(_)(_)(_)    (_)(_)(_) (_)(_)(_)(_)(_)                       (_)(_)(_)(_)    (_)(_)(_)  (_)(_)        (_)(_)    (_)       
                                                _  _  _  _  _  _  _                                                               
                                               (_)(_)(_)(_)(_)(_)(_)                                                              
"
    echo -e "\033[0m"  # Reset text color
}

# Function to validate domain name
is_valid_domain() {
    local domain="$1"
    if [[ "$domain" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 0  # Valid domain name
    else
        return 1  # Invalid domain name
    fi
}

# Prompt the user to enter a domain name and validate it
echo -e "\033[1;34m"
read -p "Enter Domain: " domain
if ! is_valid_domain "$domain"; then
    echo -e "\033[1;31mError: Invalid domain name. Please enter a valid domain.\033[0m"
    exit 1
fi

# Define the output directory
output_directory="subdomain_results"

# Create the output directory if it doesn't exist
mkdir -p "$output_directory"

# Function to perform enumeration for a domain and save results
enumerate_domain() {
    local domain="$1"
    local output_dir="$2"
    
    # Create a directory for the domain if it doesn't exist
    mkdir -p "$output_dir/$domain"

    # Display the custom "subsank" banner
    display_banner

    # Enumeration using subfinder
    Running "Subfinder"
    subfinder -d "$domain" > "$output_dir/$domain/sub.txt"
    print_progress 40

    # Enumeration using assetfinder
    Running "Assetfinder"
    assetfinder -subs-only "$domain" | anew "$output_dir/$domain/sub.txt"
    print_progress 60

    # Enumeration using finddomain (assuming you have this tool)
    Running "Finddomain"
    finddomain -t "$domain" | anew "$output_dir/$domain/sub.txt"
    print_progress 80

    # Enumeration using gau, unfurl, and curl
    Running "Enumeration with gau, unfurl, and curl"
    gau "$domain" | unfurl -u domains | sort -u | anew "$output_dir/$domain/sub.txt"
    print_progress 95

    # Enumeration using waybackurls
    Running "Waybackurls"
    waybackurls "$domain" | unfurl -u domains | anew "$output_dir/$domain/sub.txt"
    print_progress 98

    # Online Subdomain Finder
    # Enumeration using crt.sh (requires jq and sed)
    Running "Enumeration with Chaos"
    chaos -silent -d "$domain" -key "$CHAOS_APIKEY" -silent | anew "$output_dir/$domain/sub.txt"

    Running "Enumeration with crt.sh"
    curl -s "https://crt.sh/?q=%25.$domain&output=json" | jq -r '.[].name_value' | sed 's/\*\.//g' | sort -u | anew "$output_dir/$domain/sub.txt"
    print_progress 100

    Running "Enumeration with Alienvault"
    curl -sk "https://otx.alienvault.com/api/v1/indicators/domain/hackerone.com/url_list?limit=100&page=1" | grep -o '"hostname": *"[^"]*' | sed 's/"hostname": "//' | anew "$output_dir/$domain/sub.txt"

    Running "Enumeration with Web Archive"
    curl -sk "http://web.archive.org/cdx/search/cdx?url=*.$domain/*&output=text&fl=original&collapse=urlkey" | awk -F/ '{gsub(/:.*/, "", $3); print $3}' | sort -u | anew "$output_dir/$domain/sub.txt"

    Running "Enumeration with Certspotter"
    curl -sk "https://api.certspotter.com/v1/issuances?domain=$domain&include_subdomains=true&expand=dns_names" | jq .[].dns_names | grep -Po "(([\w.-]*)\.([\w]*)\.([A-z]))\w+" | anew "$output_dir/$domain/sub.txt"

    Running "Enumeration with JLDC"
    curl -sk "https://jldc.me/anubis/subdomains/$domain" | grep -Po "((http|https):\/\/)?(([\w.-]*)\.([\w]*)\.([A-z]))\w+" | anew "$output_dir/$domain/sub.txt"

    Running "Enumeration with HackerTarget"
    curl -sk "https://api.hackertarget.com/hostsearch/?q=$domain" | unfurl domains | anew "$output_dir/$domain/sub.txt"

    #Running "Enumeration with ThreatCrowd"
    #curl -sk "https://www.threatcrowd.org/searchApi/v2/domain/report/?domain=$domain" | jq -r '.subdomains' | grep -o "\w.*$domain" | anew "$output_dir/$domain/sub.txt"

    Running "Enumeration With Anubis"
    curl -sk "https://jldc.me/anubis/subdomains/$domain" | jq -r '.' | grep -o "\w.*$domain" | anew "$output_dir/$domain/sub.txt"

    Running "Enumeration with ThreatMiner"
    curl -sk "https://api.threatminer.org/v2/domain.php?q=$domain&rt=5" | jq -r '.results[]' | grep -o "\w.*$domain" | anew "$output_dir/$domain/sub.txt"

    Running "Enumeration with WhoISXML"
    curl -sk "https://subdomains.whoisxmlapi.com/api/v1?apiKey=at_dNZPaaEN3JFHQJ2OhnMjudlobHxNq&domainName=$domain" | jq -r '.result.records[]?.domain' | grep -oP '\S+\.\S+\.\S+' | sort -u | anew "$output_dir/$domain/sub.txt"
   

   # Enumeration using amass
    Running "Amass"
    amass enum -d "$domain" | anew "$output_dir/$domain/sub.txt"
    print_progress 20

    Running "Enumeration using xsubfind3r"
    xsubfind3r -d "$domain" -t 100 | grep -oP '\b(?:\w+\.)+\w+\b' | anew "$output_dir/$domain/sub.txt"
    print_progress 100


    #Brute Force 
    Running "Pure Dns"
    #cat wordlist.txt | puredns bruteforce "$domain" | anew "$output_dir/$domain/sub.txt"
    #cat "$output_dir/$domain/sub.txt" | httpx "$output_dir/$domain/alivesub.txt"

    #shuffledns -silent -d "$domain" -w "$wordlist" -r "$resolvers" -silent | anew "$output_dir/$domain/sub.txt"
    
    #Checking Alive Domain 
    
    Running "--------httpx-----------"
    sudo cat "$output_dir/$domain/sub.txt" | httpx | tee alive.txt 

    

}

# Call the enumerate_domain function
enumerate_domain "$domain" "$output_directory"


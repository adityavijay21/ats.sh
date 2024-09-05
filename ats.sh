#!/bin/bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Function to print colored text
print_color() {
    printf "${!1}${2}${NC}\n"
}

# Function to check if a file exists
check_file_exists() {
    if [ ! -f "$1" ]; then
        print_color "RED" "Error: File '$1' not found."
        exit 1
    fi
}

# Function to check file format
check_file_format() {
    file_extension="${1##*.}"
    if [[ "$file_extension" == "pdf" ]]; then
        print_color "GREEN" "✓ File is in PDF format (Excellent for ATS)"
        return 10
    elif [[ "$file_extension" == "docx" ]]; then
        print_color "YELLOW" "⚠ File is in DOCX format (Good, but PDF is preferred)"
        return 8
    else
        print_color "RED" "✗ File is not in PDF or DOCX format. Many ATS may have trouble parsing it."
        return 0
    fi
}

# Function to extract text from PDF or DOCX
extract_text() {
    file_extension="${1##*.}"
    if [[ "$file_extension" == "pdf" ]]; then
        pdftotext "$1" - 2>/dev/null || print_color "RED" "Error: pdftotext command not found. Please install poppler-utils."
    elif [[ "$file_extension" == "docx" ]]; then
        unzip -p "$1" word/document.xml | sed -e 's/<[^>]\{1,\}>//g; s/[^[:print:]\n]//g' 2>/dev/null || print_color "RED" "Error: unzip command not found. Please install unzip."
    else
        cat "$1"
    fi
}

# Function to check for common ATS-friendly elements
check_ats_elements() {
    local content="$1"
    local score=0

    print_color "BLUE" "\n${BOLD}Checking ATS-Friendly Elements:${NC}"

    # Check for contact information
    if [[ "$content" =~ [0-9]{3}[-.]?[0-9]{3}[-.]?[0-9]{4} ]]; then
        print_color "GREEN" "✓ Phone number detected"
        ((score+=5))
    else
        print_color "RED" "✗ No phone number detected"
    fi

    if [[ "$content" =~ [A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4} ]]; then
        print_color "GREEN" "✓ Email address detected"
        ((score+=5))
    else
        print_color "RED" "✗ No email address detected"
    fi

    # Check for LinkedIn profile
    if [[ "$content" =~ linkedin\.com/in/[A-Za-z0-9-]+ ]]; then
        print_color "GREEN" "✓ LinkedIn profile detected"
        ((score+=5))
    else
        print_color "YELLOW" "⚠ No LinkedIn profile detected"
    fi

    # Check for section headers
    local headers=("Experience" "Education" "Skills" "Projects" "Certifications" "Summary" "Objective")
    for header in "${headers[@]}"; do
        if [[ "$content" =~ $header ]]; then
            print_color "GREEN" "✓ '$header' section detected"
            ((score+=3))
        else
            print_color "YELLOW" "⚠ No '$header' section detected"
        fi
    done

    # Check for bullet points
    if [[ "$content" =~ [•·-] ]]; then
        print_color "GREEN" "✓ Bullet points detected"
        ((score+=5))
    else
        print_color "RED" "✗ No bullet points detected"
    fi

    # Check for appropriate length (assuming 1-2 pages is ideal)
    local line_count=$(echo "$content" | wc -l)
    if [ $line_count -ge 40 ] && [ $line_count -le 120 ]; then
        print_color "GREEN" "✓ Resume length is ideal (approximately 1-2 pages)"
        ((score+=10))
    elif [ $line_count -gt 120 ] && [ $line_count -le 180 ]; then
        print_color "YELLOW" "⚠ Resume might be slightly long"
        ((score+=5))
    else
        print_color "RED" "✗ Resume length is not optimal (too short or too long)"
    fi

    # Check for common action verbs
    local action_verbs=("Achieved" "Improved" "Trained" "Managed" "Created" "Increased" "Decreased" "Developed" "Implemented" "Coordinated")
    local verb_count=0
    for verb in "${action_verbs[@]}"; do
        if [[ "$content" =~ $verb ]]; then
            ((verb_count++))
        fi
    done
    if [ $verb_count -ge 5 ]; then
        print_color "GREEN" "✓ Good use of action verbs"
    elif [ $verb_count -ge 3 ]; then
        print_color "YELLOW" "⚠ Moderate use of action verbs"
    else
        print_color "RED" "✗ Limited use of action verbs"
    fi
    score=$((score + verb_count * 2))

    # Check for quantifiable results
    if [[ "$content" =~ [0-9]+% ]] || [[ "$content" =~ \$[0-9]+ ]]; then
        print_color "GREEN" "✓ Quantifiable results detected"
        ((score+=10))
    else
        print_color "RED" "✗ No quantifiable results detected"
    fi

    echo $score
}

# Function to check for keyword density
check_keyword_density() {
    local content="$1"
    local keywords="$2"
    local score=0
    
    print_color "BLUE" "\n${BOLD}Analyzing Keyword Density:${NC}"
    
    for keyword in $keywords; do
        keyword_count=$(echo "$content" | grep -io "$keyword" | wc -l)
        if [ $keyword_count -eq 0 ]; then
            print_color "RED" "✗ Keyword '$keyword' not found"
        elif [ $keyword_count -ge 1 ] && [ $keyword_count -le 3 ]; then
            print_color "GREEN" "✓ Keyword '$keyword' appears $keyword_count time(s) (Good density)"
            ((score+=2))
        elif [ $keyword_count -gt 3 ]; then
            print_color "YELLOW" "⚠ Keyword '$keyword' appears $keyword_count times (Potential keyword stuffing)"
            ((score+=1))
        fi
    done

    echo $score
}

# Function to display banner and ATS score
display_banner_and_score() {
    clear
    print_color "CYAN" "
██████╗ ███████╗███████╗██╗  ██╗██╗   ██╗███╗   ███╗███████╗
██╔══██╗██╔════╝██╔════╝╚██╗██╔╝██║   ██║████╗ ████║██╔════╝
██████╔╝█████╗  ███████╗ ╚███╔╝ ██║   ██║██╔████╔██║█████╗  
██╔══██╗██╔══╝  ╚════██║ ██╔██╗ ██║   ██║██║╚██╔╝██║██╔══╝  
██║  ██║███████╗███████║██╔╝ ██╗╚██████╔╝██║ ╚═╝ ██║███████╗
╚═╝  ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝
                                                            
     ███████╗██╗  ██╗██████╗ ███████╗██████╗ ████████╗     
     ██╔════╝╚██╗██╔╝██╔══██╗██╔════╝██╔══██╗╚══██╔══╝     
     ███████╗ ╚███╔╝ ██████╔╝█████╗  ██████╔╝   ██║       
     ╚════██║ ██╔██╗ ██╔═══╝ ██╔══╝  ██╔══██╗   ██║       
     ███████║██╔╝ ██╗██║     ███████╗██║  ██║   ██║       
     ╚══════╝╚═╝  ╚═╝╚═╝     ╚══════╝╚═╝  ╚═╝   ╚═╝        
"
    print_color "WHITE" "                 Advanced Resume Optimization for Applicant Tracking Systems"
    print_color "WHITE" "                 ========================================================"
    echo
    print_color "MAGENTA" "                          ${BOLD}ATS Friendliness Score: $1/100${NC}"
    echo
    print_color "YELLOW" "Type 'report' for a detailed analysis or 'exit' to quit:"
}

# Function to get user confirmation
get_user_confirmation() {
    read -p "Do you want to proceed with the analysis? (y/n): " response
    case $response in
        [Yy]* ) ;;
        [Nn]* ) exit 0 ;;
        * ) print_color "RED" "Please answer yes or no." ; exit 1 ;;
    esac
}

# Main script
if [ $# -lt 2 ]; then
    print_color "RED" "Usage: $0 <resume_file> <job_keywords>"
    exit 1
fi

resume_file="$1"
job_keywords="${@:2}"

check_file_exists "$resume_file"

format_score=0
check_file_format "$resume_file"
format_score=$?

content=$(extract_text "$resume_file")

ats_score=$(check_ats_elements "$content")
keyword_score=$(check_keyword_density "$content" "$job_keywords")

total_score=$((format_score + ats_score + keyword_score))

# Normalize score to 100
total_score=$((total_score * 100 / 150))

display_banner_and_score "$total_score"

while true; do
    read -p "> " command
    case $command in
        report)
            print_color "BLUE" "\n${BOLD}Detailed ATS Analysis Report:${NC}"
            
            if [ $total_score -ge 80 ]; then
                print_color "GREEN" "Overall: Great job! Your resume appears to be very ATS-friendly."
            elif [ $total_score -ge 60 ]; then
                print_color "YELLOW" "Overall: Your resume is somewhat ATS-friendly, but there's room for improvement."
            else
                print_color "RED" "Overall: Your resume may not be very ATS-friendly. Consider making some improvements."
            fi

            print_color "CYAN" "\n${BOLD}Strengths:${NC}"
            # Add logic to list strengths based on checks

            print_color "YELLOW" "\n${BOLD}Areas for Improvement:${NC}"
            if [ $format_score -lt 8 ]; then
                print_color "YELLOW" "• Consider saving your resume as a PDF file for better ATS compatibility."
            fi
            if [[ ! "$content" =~ [0-9]{3}[-.]?[0-9]{3}[-.]?[0-9]{4} ]]; then
                print_color "RED" "• Make sure your phone number is clearly visible on your resume."
            fi
            if [[ ! "$content" =~ [A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4} ]]; then
                print_color "RED" "• Include your email address prominently on your resume."
            fi
            if [[ ! "$content" =~ linkedin\.com/in/[A-Za-z0-9-]+ ]]; then
                print_color "YELLOW" "• Consider adding your LinkedIn profile URL to your resume."
            fi
            local headers=("Experience" "Education" "Skills" "Projects" "Certifications" "Summary" "Objective")
            for header in "${headers[@]}"; do
                if [[ ! "$content" =~ $header ]]; then
                    print_color "YELLOW" "• Consider adding a '$header' section to your resume."
                fi
            done
            if [[ ! "$content" =~ [•·-] ]]; then
                print_color "RED" "• Use bullet points to highlight key achievements and responsibilities."
            fi
            line_count=$(echo "$content" | wc -l)
            if [ $line_count -lt 40 ] || [ $line_count -gt 180 ]; then
                print_color "YELLOW" "• Aim for a resume length of about 1-2 pages (40-180 lines in this check)."
            fi
            if [[ ! "$content" =~ [0-9]+% ]] && [[ ! "$content" =~ \$[0-9]+ ]]; then
                print_color "RED" "• Try to include more quantifiable achievements (e.g., percentages, dollar amounts)."
            fi

            print_color "MAGENTA" "\n${BOLD}Keyword Analysis:${NC}"
            check_keyword_density "$content" "$job_keywords"

            print_color "GREEN" "\n${BOLD}Next Steps:${NC}"
            print_color "GREEN" "1. Address the areas for improvement mentioned above."
            print_color "GREEN" "2. Tailor your resume for each job application."
            print_color "GREEN" "3. Use industry-specific terminology relevant to the job."
            print_color "GREEN" "4. Ensure your resume is free of spelling and grammatical errors."
            print_color "GREEN" "5. Keep formatting simple and consistent throughout the document."

            echo
            print_color "YELLOW" "Type 'report' to see this analysis again or 'exit' to quit:"
            ;;
        exit)
            print_color "CYAN" "Thank you for using RESXUME ATS Expert! Good luck with your job search!"
            exit 0
            ;;
        *)
            print_color "RED" "Invalid command. Type 'report' for the detailed analysis or 'exit' to quit."
            ;;
    esac
done

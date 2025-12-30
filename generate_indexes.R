
# PROMPT
# Write a function that will use the attached table to create an index.html file in every directory listed as a value in target_dir.
# In each of these directories there may exist image files that end in "jpe" "jpg" or "jpeg".  There may also exist supplementary PDF files.
# The index file for each row should be laid out according to these rules:
# 1. Each column except 'target_dir' that has a non-empty value should appear as an attribute in a vertical table.
# 1a. Instead of putting "Title" in the table, use that value as the title for the page.
# 2. The table will have a column with the attribute name and a column with the attribute value.
# 3. For the Links attribute, put a hyperlink in the value column for each link listed.  The name of the link should be the hostname part of the URL, and the href should be the link.
# 4. Next to the table should be a Link to each PDF file found in the directory.
# 5. The images in the directory should be displayed in the HTML file with a maximum size of 600 pixels wide, each.
# 6. If an image is clicked it should open a popup window with the image in full size.
# 7. The title of each page should be taken from the "Title" column.
# 
# The html file should be laid out neatly with CSS classes assigned to elements.  In addition to the R code, generate a CSS file to put in the works directory which will give a clean minimalist but pleasing aesthetic to all the index files, each of which will reference the CSS file from the "works" directory.
# Make the view responsive so it looks okay in mobile apps.

library(readr)
library(dplyr)
library(stringr)
library(fs)
library(htmltools)
library(urltools)

# --- Configuration ---
csv_file <- "deploy_info.csv"
works_root <- "works"
css_filename <- "styles.css"

# --- 1. Load Data ---
if (!file.exists(csv_file)) stop("deploy_info.csv not found!")
deploy_data <- read_csv(csv_file, show_col_types = FALSE)

# --- 1a. Extract Owner List for Navbar ---
# Extract Owner from target_dir (format: works/Owner/Artist--ID)
deploy_data <- deploy_data %>%
    mutate(
        Owner_Dir = sapply(str_split(target_dir, "/"), function(x) {
            if (length(x) >= 2) x[2] else NA_character_
        })
    )

# Get unique owners list for navbar (filter out any NA values)
owners_list <- deploy_data %>% 
    pull(Owner_Dir) %>% 
    .[!is.na(.)] %>%
    unique() %>% 
    sort()

# --- 2. Create CSS File ---
if (!dir.exists(works_root)) dir.create(works_root, recursive = TRUE)

css_content <- "
/* Clean Minimalist Aesthetic */
:root {
    --primary-color: #2c3e50;
    --secondary-color: #34495e;
    --accent-color: #3498db;
    --bg-color: #fcfcfc;
    --text-color: #333;
    --border-color: #e0e0e0;
}

body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
    line-height: 1.6;
    color: var(--text-color);
    background-color: var(--bg-color);
    margin: 0;
    padding: 20px;
    padding-top: 80px; /* Space for the fixed navbar */
}

/* Navbar Styling */
.navbar {
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    background-color: var(--primary-color);
    padding: 1rem 2rem;
    box-shadow: 0 2px 5px rgba(0,0,0,0.2);
    z-index: 1000;
    display: flex;
    align-items: center;
    justify-content: center;
    flex-wrap: wrap;
    gap: 20px;
}

.navbar a {
    color: white;
    text-decoration: none;
    font-weight: 500;
    font-size: 1.1rem;
    padding: 5px 10px;
    border-radius: 4px;
    transition: background-color 0.2s;
}

.navbar a:hover {
    background-color: rgba(255,255,255,0.1);
}

.container {
    max-width: 1200px;
    margin: 0 auto;
    background: white;
    padding: 2rem;
    border-radius: 8px;
    box-shadow: 0 4px 6px rgba(0,0,0,0.05);
}

h1 {
    color: var(--primary-color);
    border-bottom: 2px solid var(--border-color);
    padding-bottom: 0.5rem;
    margin-top: 0;
    font-size: 2rem;
}

/* Layout Grid */
.content-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 3rem;
    margin-top: 2rem;
}

@media (max-width: 768px) {
    .content-grid {
        grid-template-columns: 1fr;
    }
}

/* Table Styling */
table.info-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 0.95rem;
}

table.info-table th {
    text-align: left;
    padding: 12px;
    background-color: #f8f9fa;
    color: var(--secondary-color);
    width: 30%;
    border-bottom: 1px solid var(--border-color);
    font-weight: 600;
}

table.info-table td {
    padding: 12px;
    border-bottom: 1px solid var(--border-color);
}

/* Links */
a {
    color: var(--accent-color);
    text-decoration: none;
    transition: color 0.2s;
}

a:hover {
    color: #2980b9;
    text-decoration: underline;
}

/* PDF Section */
.pdf-section {
    margin-top: 2rem;
    padding: 1rem;
    background-color: #f8f9fa;
    border-radius: 4px;
    border: 1px solid #eee;
}

.pdf-section h4 {
    margin-top: 0;
    color: var(--secondary-color);
    font-size: 1rem;
    margin-bottom: 10px;
}

.pdf-link {
    display: block;
    margin-bottom: 0.5rem;
    font-weight: 500;
    display: flex;
    align-items: center;
}

.pdf-icon {
    margin-right: 8px;
    font-size: 1.2rem;
}

/* Image Gallery */
.gallery-section {
    display: flex;
    flex-direction: column;
    align-items: center;
}

.gallery {
    display: flex;
    flex-direction: column;
    gap: 20px;
    align-items: center;
    width: 100%;
}

.gallery-img {
    max-width: 600px;
    width: 100%;
    height: auto;
    border-radius: 4px;
    box-shadow: 0 4px 8px rgba(0,0,0,0.1);
    cursor: pointer;
    transition: transform 0.2s;
    object-fit: contain;
}

.gallery-img:hover {
    transform: scale(1.02);
}

/* Popup/Lightbox */
.lightbox {
    display: none;
    position: fixed;
    z-index: 1000;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background-color: rgba(0,0,0,0.9);
    align-items: center;
    justify-content: center;
    padding: 20px;
    box-sizing: border-box;
}

.lightbox-img {
    max-width: 95%;
    max-height: 95vh;
    box-shadow: 0 0 20px rgba(0,0,0,0.5);
    border-radius: 4px;
}

.close-btn {
    position: absolute;
    top: 20px;
    right: 30px;
    color: white;
    font-size: 40px;
    cursor: pointer;
    font-weight: bold;
    z-index: 1001;
    background: rgba(0,0,0,0.5);
    width: 50px;
    height: 50px;
    border-radius: 50%;
    text-align: center;
    line-height: 50px;
}

.close-btn:hover {
    background: rgba(255,255,255,0.2);
}
"

write_lines(css_content, file.path(works_root, css_filename))
message("CSS file created at: ", file.path(works_root, css_filename))


# --- 3. Helper Functions ---

# Function to parse and generate links for the Links column
format_links <- function(links_str) {
    if (is.na(links_str) || links_str == "") return("")
    
    # Split by space
    urls <- str_split(links_str, "\\s+")[[1]]
    
    link_tags <- lapply(urls, function(url) {
        if (url == "") return(NULL)
        # Extract hostname for display
        host <- url_parse(url)$domain
        if (is.na(host)) host <- "Link"
        
        div(a(href = url, target = "_blank", host))
    })
    
    do.call(tagList, link_tags)
}

# --- 4. Process Each Row ---

for (i in 1:nrow(deploy_data)) {
    row <- deploy_data[i, ]
    target_dir <- row$target_dir
    
    # Safety check
    if (is.na(target_dir)) next
    
    # Check if directory exists, if not create it (though logic implies it should exist from previous steps)
    if (!dir.exists(target_dir)) dir.create(target_dir, recursive = TRUE)
    
    # Determine where the CSS is relative to this directory
    # Works structure: works/Owner/Directory
    # So we typically need ../../styles.css
    # Use fs::path_rel for robustness if needed, but manual is fine for fixed structure
    css_rel_path <- "../../styles.css" 
    
    # --- Gather Files ---
    images <- dir_ls(target_dir, regexp = "(?i)\\.jp.*$") %>% path_file()
    pdfs <- dir_ls(target_dir, regexp = "(?i)\\.pdf$") %>% path_file()
    
    # --- Build Table Data ---
    # Exclude target_dir and Title (since Title is page title)
    display_cols <- row %>% select(-target_dir, -Title)
    
    table_rows <- lapply(names(display_cols), function(col_name) {
        val <- display_cols[[col_name]]
        
        # Skip empty/NA
        if (is.na(val) || as.character(val) == "") return(NULL)
        
        # Special handling for Links column
        content <- if (col_name == "Links") {
            format_links(as.character(val))
        } else {
            as.character(val)
        }
        
        tags$tr(
            tags$th(col_name),
            tags$td(content)
        )
    })
    # Remove NULLs
    table_rows <- table_rows[!sapply(table_rows, is.null)]
    
    
    # --- Generate Navbar ---
    navbar <- div(class = "navbar",
                  # Add link to main index
                  a(href = "../../index.html", "Home"),
                  # Add links for each owner section in master index
                  lapply(owners_list, function(owner) {
                      # Use an ID based on the owner name (cleaned)
                      clean_id <- str_replace_all(owner, "[^a-zA-Z0-9]", "")
                      a(href = paste0("../../index.html#", clean_id), owner)
                  })
    )
    
    # --- Build HTML Page ---
    page_title <- if(is.na(row$Title)) paste("Record", row$ID) else row$Title
    
    page <- tags$html(
        tags$head(
            tags$title(page_title),
            tags$meta(charset = "utf-8"),
            tags$meta(name = "viewport", content = "width=device-width, initial-scale=1"),
            tags$link(rel = "stylesheet", href = css_rel_path),
            # Add simple JS for Lightbox
            tags$script(HTML("
        function openLightbox(imgSrc) {
            document.getElementById('lightbox-img').src = imgSrc;
            document.getElementById('lightbox').style.display = 'flex';
        }
        function closeLightbox() {
            document.getElementById('lightbox').style.display = 'none';
        }
        // Close lightbox when clicking outside image
        window.onclick = function(event) {
            var modal = document.getElementById('lightbox');
            if (event.target == modal) {
                modal.style.display = 'none';
            }
        }
      "))
        ),
        tags$body(
            navbar,
            div(class = "container",
                
                h1(page_title),
                
                div(class = "content-grid",
                    
                    # Left Column: Table + PDFs
                    div(class = "info-section",
                        tags$table(class = "info-table",
                                   tags$tbody(table_rows)
                        ),
                        
                        # PDFs
                        if (length(pdfs) > 0) {
                            div(class = "pdf-section",
                                h4("Documents"),
                                lapply(pdfs, function(pdf) {
                                    div(class = "pdf-link",
                                        span(class = "pdf-icon", "📄"),
                                        a(href = pdf, target = "_blank", pdf)
                                    )
                                })
                            )
                        }
                    ),
                    
                    # Right Column: Images
                    div(class = "gallery-section",
                        if (length(images) > 0) {
                            div(class = "gallery",
                                lapply(images, function(img) {
                                    tags$img(src = img, 
                                             class = "gallery-img", 
                                             onclick = sprintf("openLightbox('%s')", img),
                                             alt = "Artwork Image")
                                })
                            )
                        } else {
                            p("No images available.", style = "color: #999; font-style: italic;")
                        }
                    )
                ),
                
                # Lightbox Container (Hidden by default)
                div(id = "lightbox", class = "lightbox",
                    span(class = "close-btn", "×", onclick = "closeLightbox()"),
                    tags$img(id = "lightbox-img", class = "lightbox-img")
                )
            )
        )
    )
    
    # Write file
    save_html(page, file.path(target_dir, "index.html"))
    message("Generated index for: ", target_dir)
}

message("Processing complete.")
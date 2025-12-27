library(readr)
library(dplyr)
library(stringr)
library(fs)
library(htmltools)

# Now write a function to create an index.html file in the docs
# directory that will contain an index to all the index files generated
# in the previous step.  Entries should be grouped by owner.  The owner
# is the name found in the second segment of target_dir, the first
# subdirectory of "works/".
# 
# Each entry in the index should have the title, artist name, the year
# in "Acquired", the year in "Distributed", and the Value.  The row
# should have a thumbnail image which is scaled down version of the
# first file found in the target directory that ends with "JPE".  The
# thumbnail should be in a 160 pixel max width and height viewport.  If
# the mouse is hovered over the thumbnail, a popup image opens that is
# 500 by 500 pixels.

library(readr)
library(dplyr)
library(stringr)
library(fs)
library(htmltools)
library(urltools)

# --- Configuration ---
csv_file <- "deploy_info.csv"
works_root <- "Works"
css_filename <- "styles.css"

# --- 1. Load Data ---
if (!file.exists(csv_file)) stop("deploy_info.csv not found!")
deploy_data <- read_csv(csv_file, show_col_types = FALSE)

# --- 2. Create CSS File ---
if (!dir.exists(works_root)) dir.create(works_root)

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
}

/* Layout Grid */
.content-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 2rem;
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
    margin-top: 1rem;
    padding: 1rem;
    background-color: #f8f9fa;
    border-radius: 4px;
}

.pdf-link {
    display: block;
    margin-bottom: 0.5rem;
    font-weight: 500;
}

.pdf-icon {
    margin-right: 8px;
    color: #e74c3c;
}

/* Image Gallery */
.gallery {
    display: flex;
    flex-direction: column;
    gap: 20px;
    align-items: center;
}

.gallery-img {
    max-width: 600px;
    width: 100%;
    height: auto;
    border-radius: 4px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    cursor: pointer;
    transition: transform 0.2s;
}

.gallery-img:hover {
    transform: scale(1.01);
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
}

.lightbox-img {
    max-width: 90%;
    max-height: 90vh;
    box-shadow: 0 0 20px rgba(0,0,0,0.5);
}

.close-btn {
    position: absolute;
    top: 20px;
    right: 30px;
    color: white;
    font-size: 40px;
    cursor: pointer;
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
    
    # Determine where the CSS is relative to this directory
    # Works structure: works/Owner/Directory
    # So we typically need ../../styles.css
    css_rel_path <- "../../styles.css" 
    
    # --- Gather Files ---
    if (dir.exists(target_dir)) {
        images <- dir_ls(target_dir, regexp = "(?i)\\.jpe?g$") %>% path_file()
        pdfs <- dir_ls(target_dir, regexp = "(?i)\\.pdf$") %>% path_file()
    } else {
        images <- character(0)
        pdfs <- character(0)
    }
    
    # --- Build Table Data ---
    # Exclude target_dir
    display_cols <- row %>% select(-target_dir)
    
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
    
    
    # --- Build HTML Page ---
    
    page <- tags$html(
        tags$head(
            tags$title(paste("Index -", row$ID)),
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
      "))
        ),
        tags$body(
            div(class = "container",
                
                h1(paste("Record", row$ID)),
                
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
                            p("No images available.")
                        }
                    )
                ),
                
                # Lightbox Container (Hidden by default)
                div(id = "lightbox", class = "lightbox", onclick = "closeLightbox()",
                    span(class = "close-btn", "×"),
                    tags$img(id = "lightbox-img", class = "lightbox-img")
                )
            )
        )
    )
    
    # Write file
    if (dir.exists(target_dir)) {
        save_html(page, file.path(target_dir, "index.html"))
        message("Generated index for: ", target_dir)
    } else {
        message("Warning: Target directory does not exist: ", target_dir)
    }
}

message("Processing complete.")
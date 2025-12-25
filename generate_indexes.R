library(readr)
library(dplyr)
library(stringr)
library(fs)
library(htmltools) # Using htmltools for safer/cleaner HTML generation

# PROMPT
# Write code that will use the attached table to create an index.html file in every directory listed as a value in target_dir.  In each of these directories there may exist image files that end in "jpe" "jpg" or "jpeg".  There may also exist supplementary PDF files.  The index file should be laid out:
#
# 1. The values in the remaining columns for the row should appear in a table for reference in the HTML file.
# 2. Next to the table should be a Link to each PDF file found in the directory.
# 3. The images in the directory should be displayed in the HTML file with a maximum size of 600 pixels wide, each.  
# 
# The html file should be laid out neatly with CSS classes assigned to elements.  In addition to the R code, generate a CSS file to put in the works directory which will give a clean minimalist but pleasing aesthetic to all the index files, which will reference the CSS file from the "works" directory.

# --- Configuration ---
csv_file <- "deploy_info.csv"
works_root <- "works"
css_filename <- "styles.css"

# --- 1. Load Data ---
if (!file.exists(csv_file)) stop("deploy_info.csv not found!")
deploy_data <- read_csv(csv_file, show_col_types = FALSE)

# --- 2. Create CSS File ---
# Ensure works directory exists
if (!dir.exists(works_root)) dir.create(works_root)

css_content <- "
body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
    line-height: 1.6;
    color: #333;
    max-width: 1000px;
    margin: 0 auto;
    padding: 2rem;
    background-color: #f4f4f9;
}
.container {
    background: white;
    padding: 3rem;
    border-radius: 8px;
    box-shadow: 0 4px 12px rgba(0,0,0,0.05);
}
header {
    margin-bottom: 2rem;
    border-bottom: 1px solid #eee;
    padding-bottom: 1rem;
}
h1 {
    color: #111;
    margin: 0 0 0.5rem 0;
    font-size: 2rem;
}
h2 {
    color: #666;
    font-weight: 400;
    margin: 0;
    font-size: 1.25rem;
}
.content-grid {
    display: flex;
    flex-wrap: wrap;
    gap: 3rem;
    margin-bottom: 3rem;
}
.data-section {
    flex: 2;
    min-width: 300px;
}
.files-section {
    flex: 1;
    min-width: 200px;
    background: #fafafa;
    padding: 1.5rem;
    border-radius: 6px;
    height: fit-content;
}
/* Table Styling */
table.info-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 0.95rem;
}
table.info-table th, table.info-table td {
    padding: 10px 15px;
    border-bottom: 1px solid #eee;
    text-align: left;
    vertical-align: top;
}
table.info-table th {
    color: #555;
    font-weight: 600;
    width: 120px;
    background-color: #fcfcfc;
}
table.info-table tr:last-child td, table.info-table tr:last-child th {
    border-bottom: none;
}
/* Links & Files */
h3.section-title {
    font-size: 0.9rem;
    text-transform: uppercase;
    letter-spacing: 1px;
    color: #888;
    margin-top: 0;
}
a.file-link {
    display: flex;
    align-items: center;
    padding: 8px 12px;
    background: white;
    border: 1px solid #ddd;
    border-radius: 4px;
    text-decoration: none;
    color: #333;
    margin-bottom: 8px;
    font-size: 0.9rem;
    transition: all 0.2s;
}
a.file-link:hover {
    border-color: #bbb;
    background: #fff;
    box-shadow: 0 2px 4px rgba(0,0,0,0.05);
}
a.file-link span.icon { margin-right: 8px; color: #e74c3c; font-weight: bold;}
/* Images */
.gallery {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 2rem;
    border-top: 1px solid #eee;
    padding-top: 2rem;
}
.img-wrapper {
    box-shadow: 0 4px 8px rgba(0,0,0,0.1);
    border-radius: 4px;
    overflow: hidden;
    line-height: 0;
}
.gallery img {
    max-width: 600px;
    width: 100%;
    height: auto;
    display: block;
}
.footer {
    margin-top: 3rem;
    text-align: center;
    font-size: 0.8rem;
    color: #aaa;
}
"

write_lines(css_content, file.path(works_root, css_filename))
message("CSS file created at: ", file.path(works_root, css_filename))


# --- 3. Generate HTML for Each Directory ---

for (i in 1:nrow(deploy_data)) {
    
    row <- deploy_data[i, ]
    
    target_dir <- row$target_dir
    
    # Ensure target directory exists (safety check)
    if (is.na(target_dir) || !dir.exists(target_dir)) {
        message("Skipping row ", i, ": Directory not found -> ", target_dir)
        next
    }
    
    # --- A. Gather Assets ---
    
    # Find Images (jpg, jpeg, jpe - case insensitive)
    images <- dir_ls(target_dir, regexp = "(?i)\\.jpe?g?$") %>% path_file()
    
    # Find PDFs
    pdfs <- dir_ls(target_dir, regexp = "(?i)\\.pdf$") %>% path_file()
    
    # --- B. Build Data Table Content ---
    
    # Exclude 'target_dir' from the display table
    display_data <- row %>% select(-target_dir)
    
    # Convert row to a long format for the table: Attribute | Value
    table_rows <- lapply(names(display_data), function(col_name) {
        val <- as.character(display_data[[col_name]])
        if (is.na(val) || val == "") return(NULL) # Skip empty fields
        tags$tr(
            tags$th(col_name),
            tags$td(val)
        )
    })
    # Remove NULLs
    table_rows <- table_rows[!sapply(table_rows, is.null)]
    
    
    # --- C. Calculate Relative Path to CSS ---
    # Assuming styles.css is in the 'works' root.
    # We use fs::path_rel to determine exact relative path from target_dir to works/styles.css
    css_path_abs <- path_abs(file.path(works_root, css_filename))
    target_dir_abs <- path_abs(target_dir)
    css_rel_path <- path_rel(css_path_abs, start = target_dir_abs)
    
    
    # --- D. Build HTML Page ---
    
    page <- tags$html(
        tags$head(
            tags$title(paste(row$Title, "-", row$Artist)),
            tags$meta(charset = "utf-8"),
            tags$meta(name = "viewport", content = "width=device-width, initial-scale=1"),
            tags$link(rel = "stylesheet", href = css_rel_path)
        ),
        tags$body(
            div(class = "container",
                
                # Header
                tags$header(
                    h1(row$Title),
                    h2(row$Artist)
                ),
                
                # Flex Container for Data + Files
                div(class = "content-grid",
                    
                    # Left: Data Table
                    div(class = "data-section",
                        tags$table(class = "info-table",
                                   tags$tbody(table_rows)
                        )
                    ),
                    
                    # Right: PDF Files (Only show section if PDFs exist)
                    if (length(pdfs) > 0) {
                        div(class = "files-section",
                            h3(class = "section-title", "Documents"),
                            lapply(pdfs, function(pdf) {
                                a(class = "file-link", href = pdf, target = "_blank",
                                  span(class = "icon", "PDF"),
                                  pdf
                                )
                            })
                        )
                    } else {
                        # Optional: Empty placeholder or nothing
                        NULL 
                    }
                ),
                
                # Bottom: Image Gallery
                if (length(images) > 0) {
                    div(class = "gallery",
                        lapply(images, function(img) {
                            div(class = "img-wrapper",
                                tags$img(src = img, alt = paste("Image of", row$Title))
                            )
                        })
                    )
                } else {
                    div(class = "footer", "No images available.")
                }
            )
        )
    )
    
    # --- E. Write File ---
    index_path <- file.path(target_dir, "index.html")
    save_html(page, index_path)
    
    message("Generated index.html for: ", row$Title)
}

message("All HTML files generated.")
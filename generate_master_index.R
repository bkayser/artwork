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


generate_master_index <- function() {
    
    # --- Configuration ---
    csv_file <- "deploy_info.csv"
    # CHANGED: Output root is now "works" instead of "docs"
    output_root <- "works"
    # works_root is effectively the same as output_root now, but used for relative logic
    works_root <- "works" 
    css_filename <- "master_styles.css"
    
    # --- 1. Load Data ---
    if (!file.exists(csv_file)) stop("deploy_info.csv not found!")
    deploy_data <- read_csv(csv_file, show_col_types = FALSE)
    
    # --- 2. Prepare Output Directory ---
    # Ensure "works" exists (it should already, but safety first)
    if (!dir.exists(output_root)) dir.create(output_root)
    
    # --- 3. Extract Owner from target_dir ---
    # target_dir format: works/Owner/Artist--ID
    # We split by "/" and take the 2nd element.
    deploy_data <- deploy_data %>%
        mutate(
            Owner_Dir = sapply(str_split(target_dir, "/"), function(x) x[2])
        )
    
    # Group by Owner
    grouped_data <- deploy_data %>% group_by(Owner_Dir)
    
    
    # --- 4. Generate CSS ---
    css_content <- "
  body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      background-color: #f4f4f9;
      color: #333;
      margin: 0;
      padding: 2rem;
  }
  .container {
      max-width: 1200px;
      margin: 0 auto;
      background: white;
      padding: 2rem;
      border-radius: 8px;
      box-shadow: 0 2px 10px rgba(0,0,0,0.05);
  }
  h1 { text-align: center; color: #2c3e50; margin-bottom: 2rem; }
  
  /* Owner Section Styling */
  .owner-section { margin-bottom: 3rem; }
  .owner-header {
      background: #2c3e50;
      color: white;
      padding: 0.75rem 1.5rem;
      border-radius: 4px;
      font-size: 1.5rem;
      margin-bottom: 1rem;
  }
  
  /* Table Styling */
  table.inventory {
      width: 100%;
      border-collapse: collapse;
      font-size: 0.9rem;
  }
  table.inventory th, table.inventory td {
      padding: 12px 15px;
      border-bottom: 1px solid #eee;
      text-align: left;
      vertical-align: middle;
  }
  table.inventory th {
      background-color: #f8f9fa;
      font-weight: 600;
      color: #555;
      position: sticky;
      top: 0;
  }
  table.inventory tr:hover { background-color: #fafafa; }
  
  /* Thumbnail & Popup Logic */
  .thumb-cell { width: 180px; text-align: center; }
  
  .img-container {
      position: relative;
      display: inline-block;
  }
  
  .thumbnail {
      max-width: 160px;
      max-height: 160px;
      width: auto;
      height: auto;
      border-radius: 4px;
      border: 1px solid #ddd;
      transition: border-color 0.2s;
      display: block;
      cursor: pointer;
  }
  
  .thumbnail:hover { border-color: #aaa; }
  
  /* The Popup Image */
  .popup-img {
      display: none; /* Hidden by default */
      position: absolute;
      z-index: 999;
      top: -100px;       /* Adjusted to center better with larger image */
      left: 170px;      /* To the right of the thumbnail */
      width: 800px;     /* CHANGED: 800px width */
      height: 800px;    /* CHANGED: 800px height */
      object-fit: contain; 
      background-color: white;
      border: 1px solid #ccc;
      box-shadow: 0 5px 20px rgba(0,0,0,0.3);
      border-radius: 4px;
      padding: 5px;
  }
  
  /* Show on hover */
  .img-container:hover .popup-img {
      display: block;
  }
  
  /* Link Styling */
  a.item-link {
      text-decoration: none;
      color: #2980b9;
      font-weight: 500;
  }
  a.item-link:hover { text-decoration: underline; }
  "
    
    write_lines(css_content, file.path(output_root, css_filename))
    message("Master CSS created at: ", file.path(output_root, css_filename))
    
    
    # --- 5. Generate HTML Content ---
    
    # Helper to find first image
    find_thumbnail <- function(dir_path) {
        if (is.na(dir_path) || !dir.exists(dir_path)) return(NULL)
        # Pattern looks for .jpe, .jpg, .jpeg case insensitive
        imgs <- dir_ls(dir_path, regexp = "(?i)\\.jpe?g$")
        if (length(imgs) > 0) return(imgs[1]) # Return the first one
        return(NULL)
    }
    
    # Build Owner Sections
    owner_sections <- lapply(group_keys(grouped_data)[[1]], function(owner) {
        
        # Get rows for this owner
        owner_rows <- grouped_data %>% filter(Owner_Dir == owner)
        
        # Create Table Rows
        table_body <- lapply(1:nrow(owner_rows), function(i) {
            r <- owner_rows[i, ]
            
            # Determine paths
            # target_dir is like "works/Owner/Artist--ID"
            # The master index is now at "works/index.html"
            # So we need to go down into "Owner/Artist--ID"
            
            # Relative path base for links in HTML
            # We just strip "works/" from the target_dir to get the relative path from works/
            # e.g. "works/Jean/..." -> "Jean/..."
            rel_path_from_root <- str_replace(r$target_dir, paste0("^", works_root, "/"), "")
            
            # Absolute path to finding the image (still needs full system path)
            abs_target_dir <- r$target_dir
            
            # Find image
            thumb_path <- find_thumbnail(abs_target_dir)
            
            # Create Image Tag
            img_tag <- if (!is.null(thumb_path)) {
                # Convert absolute file path to relative path for HTML
                # thumb_path is like "works/Owner/Artist--ID/img.jpg"
                # We need "Owner/Artist--ID/img.jpg" (relative to works/index.html)
                img_rel_path <- str_replace(thumb_path, paste0("^", works_root, "/"), "")
                
                div(class = "img-container",
                    tags$img(src = img_rel_path, class = "thumbnail", alt = "Thumbnail"),
                    tags$img(src = img_rel_path, class = "popup-img", alt = "Popup")
                )
            } else {
                div(class = "img-container", span(style="color:#ccc; font-size:0.8rem;", "No Image"))
            }
            
            # Create Detail Link (to the individual index.html generated previously)
            detail_link <- a(class = "item-link", href = file.path(rel_path_from_root, "index.html"), r$Title)
            
            # --- FORMAT VALUE COLUMN ---
            val_raw <- r$Value
            if (is.na(val_raw) || val_raw == "") {
                formatted_value <- "-"
            } else {
                # Attempt to clean and parse as numeric
                # remove existing $ or ,
                clean_val <- str_replace_all(as.character(val_raw), "[$,]", "")
                num_val <- suppressWarnings(as.numeric(clean_val))
                
                if (is.na(num_val)) {
                    # If it's text (e.g. "Unknown"), keep as is
                    formatted_value <- as.character(val_raw)
                } else {
                    # Round to whole dollars and format with commas
                    # trim=TRUE removes leading spaces from format()
                    formatted_value <- paste0("$", format(round(num_val, 0), big.mark = ",", scientific = FALSE, trim = TRUE))
                }
            }
            
            tags$tr(
                tags$td(class = "thumb-cell", img_tag),
                tags$td(detail_link),
                tags$td(r$Artist),
                tags$td(r$Acquired),
                tags$td(r$Distributed),
                tags$td(formatted_value) # Use new formatted value
            )
        })
        
        # Assemble Section
        div(class = "owner-section",
            div(class = "owner-header", owner),
            tags$table(class = "inventory",
                       tags$thead(
                           tags$tr(
                               tags$th("Image"),
                               tags$th("Title"),
                               tags$th("Artist"),
                               tags$th("Acquired"),
                               tags$th("Distributed"),
                               tags$th("Value")
                           )
                       ),
                       tags$tbody(table_body)
            )
        )
    })
    
    
    # --- 6. Assemble Final Page ---
    
    page <- tags$html(
        tags$head(
            tags$title("Master Inventory Index"),
            tags$meta(charset = "utf-8"),
            tags$meta(name = "viewport", content = "width=device-width, initial-scale=1"),
            tags$link(rel = "stylesheet", href = css_filename)
        ),
        tags$body(
            div(class = "container",
                h1("Inventory Index by Owner"),
                owner_sections
            )
        )
    )
    
    # CHANGED: Save to output_root (works/) instead of docs_root
    save_html(page, file.path(output_root, "index.html"))
    message("Master Index generated at: ", file.path(output_root, "index.html"))
}

# Run the function
generate_master_index()
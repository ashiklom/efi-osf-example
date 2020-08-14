library(httr)

# This is the URL of your project.
node_id <- "xtejp"

# This is a token file.
token <- readLines(".token")

# Test authentication
auth_hdr <- add_headers(Authorization = sprintf("Bearer %s", token))
auth_raw <- GET(
  "https://api.osf.io/v2/users/me",
  auth_hdr
)
auth_result <- jsonlite::fromJSON(content(auth_raw, "text"))
print(auth_result$data$attributes$full_name)


# Create a folder. This returns some useful links
mkdir_raw <- PUT(
  sprintf("http://files.osf.io/v1/resources/%s/providers/osfstorage/", node_id),
  auth_hdr,
  query = list(kind = "folder", name = "csv-upload-test")
)
mkdir_res <- content(mkdir_raw, "parsed")

# Create a file and upload it to the folder above
n <- 100
x <- rnorm(n)
y <- x * 2 + 3 + rnorm(n, 0, 1.5)
dat <- data.frame(x = x, y = y)
write.csv(dat, "file-01.csv")

upload_raw <- PUT(
  mkdir_res$data$links$upload,
  auth_hdr,
  query = list(name = "file-01.csv"),
  body = upload_file("file-01.csv")
)
upload_res <- content(upload_raw, "parsed")

# Now, let's update the y values slightly
dat2 <- dat
dat2$y <- dat2$x * 3 + 2.5 + rnorm(n, 0, 1.3)
write.csv(dat2, "file-01.csv")

# ...and upload the updated file to the same location. Note that because we
# re-use the upload link from the last API call, we don't provide the name.
upload2_raw <- PUT(
  upload_res$data$links$upload,
  auth_hdr,
  body = upload_file("file-01.csv")
)
upload2_res <- content(upload2_raw, "parsed")

# This will add a new version to that file.

# Retrieve information about the file. If we know that URL, this is easy:
# Note that, for public repos, retrieving info doesn't require authentication.
meta1_raw <- GET(upload_res$data$links$download, query = list(meta = ""))
meta1 <- content(meta1_raw, "parsed")
meta1$data$attributes$name  # File name
meta1$data$attributes$materialized  # Human-readable path
meta1$data$attributes$modified  # Last modified timestamp
meta1$data$attributes$extra$version  # File version
meta1$data$attributes$extra$hashes  # MD5 and SHA hashes

# Download the file
GET(upload2_res$data$links$download, write_disk("osf-file.csv"))
head(read.csv("osf-file.csv")[, c("x", "y")])

# This shows information for the latest version. To retrieve all version
# information, replace `meta` with `versions`.
meta2_raw <- GET(upload_res$data$links$download, query = list(versions = ""))
meta2 <- content(meta2_raw, "parsed")
length(meta2$data)
lapply(meta2$data, "[[", c("attributes", "version"))

# We can download specific versions of a file by adding the `version` query
# parameter.
GET(upload2_res$data$links$download, write_disk("osf-file-v1.csv"),
    query = list(version = 1))
GET(upload2_res$data$links$download, write_disk("osf-file-v2.csv"),
    query = list(version = 2))

osf_d1 <- read.csv("osf-file-v1.csv")
osf_d2 <- read.csv("osf-file-v2.csv")
plot(y ~ x, data = osf_d1, ylim = range(osf_d1$y, osf_d2$y))
points(osf_d2$x, osf_d2$y, col = "red")
legend("topleft", c("v1", "v2"), col = c("black", "red"), pch = 1)

# If we don't know the exact URL, we can use the API to search the repository
ls_raw <- GET(sprintf(
    "https://files.osf.io/v1/resources/%s/providers/osfstorage/",
    node_id
  ), query = list(meta = ""))
ls_res <- content(ls_raw, "parsed")
length(ls_res$data)
# `data` is a list with one elemnt per file in the root. Below, we can generate
# a list of paths and URLs
folders <- lapply(
  ls_res$data,
  function(x) list(path = x$attributes$materialized,
                   url = x$links$move)
)
print(folders)

# Repeat this for the csv-upload-test folder.
ls2_raw <- GET(folders[[1]]$url, query = list(meta = ""))
ls2_res <- content(ls2_raw, "parsed")
# The results here have the same structure -- one `data` element per file
files <- lapply(
  ls_res$data,
  function(x) list(path = x$attributes$materialized,
                   url = x$links$move)
)
print(files)

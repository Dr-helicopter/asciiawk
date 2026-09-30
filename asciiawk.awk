function delimeter_bock_dump(lines, len, width, style, end_style) {
	width++
	printf("%s %-*s%s\n", style, width," ", end_style)

	for (i=0;i<len;i++)
		printf("%s %-*s%s\n", style, 
		   width,lines[i], end_style)
	printf("%s %-*s%s\n", style, width," ", end_style)

}

BEGIN {
		style_none="\033[0m"
		style_literal="\033[48;5;0m"
		style_listing="\033[48;5;0m"
		fill_line="\033[K"

		style_quote   = "\033[38;5;7m\033[48;5;0m"
		style_example = "\033[38;5;11m\033[48;5;0m"
		style_sidebar = "\033[38;5;14m\033[48;5;0m"
		style_open    = style_listing
	}

{
    gsub(/\t/, "    ")
    sub(/[ \t\r]+$/, "")
}

in_comment_block == 1 {
		if (/^\/\/\/\/+[[:space:]]*$/ && $1 == comment_block_temin) {
				in_comment_block = 0;
			}
		next
	}

in_literal_block == 1 {
		if (/^\.{4,}[[:space:]]*$/ && $1 == literal_block_temin) {
			in_literal_block= 0;
			delimeter_bock_dump(block_lines, block_index, 
				block_max_len, style_literal, style_none)
			next
		}

		block_lines[block_index++] = $0
		if (length($0) > block_max_len)
			block_max_len = length($0)
		next
	}

in_listing_block == 1 {
		if (/^-{4,}[[:space:]]*$/ && $1 == listing_block_temin) {
			in_listing_block= 0;

			delimeter_bock_dump(block_lines, block_index, 
				block_max_len, style_listing, style_none)
			next
		}

		block_lines[block_index++] = $0
		if (length($0) > block_max_len)
			block_max_len = length($0)
		next
	}

in_example_block == 1 {
		if (/^={4,}[[:space:]]*$/ && $1 == example_block_temin) {
			in_example_block= 0;

			delimeter_bock_dump(block_lines, block_index, 
				block_max_len, style_example, style_none)
			next
		}

		block_lines[block_index++] = $0
		if (length($0) > block_max_len)
			block_max_len = length($0)
		next
	}

in_quote_block == 1 {
		if (/^_{4,}[[:space:]]*$/ && $1 == quote_block_temin) {
			in_quote_block= 0;

			delimeter_bock_dump(block_lines, block_index, 
				block_max_len, style_quote, style_none)
			next
		}

		block_lines[block_index++] = $0
		if (length($0) > block_max_len)
			block_max_len = length($0)
		next
	}

in_sidebar_block == 1 {
		if (/^\*{4,}[[:space:]]*$/ && $1 == sidebar_block_temin) {
			in_sidebar_block= 0;

			delimeter_bock_dump(block_lines, block_index, 
				block_max_len, style_sidebar, style_none)
			next
		}

		block_lines[block_index++] = $0
		if (length($0) > block_max_len)
			block_max_len = length($0)
		next
	}

in_open_block == 1 {
		if (/^--[[:space:]]*$/ && $1 == open_block_temin) {
			in_open_block= 0;

			delimeter_bock_dump(block_lines, block_index, 
				block_max_len, style_open, style_none)
			next
		}

		block_lines[block_index++] = $0
		if (length($0) > block_max_len)
			block_max_len = length($0)
		next
	}




# block detections
/^\/{4,}[[:space:]]*$/ {
		in_comment_block = 1;
		comment_block_temin = $1
		next
	}

/^\.{4,}[[:space:]]*$/ {
		in_literal_block = 1;
		literal_block_temin = $1
		block_max_len=1
		block_index=0
		next
	}

/^-{4,}[[:space:]]*$/ {
		in_listing_block = 1;
		listing_block_temin = $1
		block_max_len=1
		block_index=0
		next
	}

/^={4,}[[:space:]]*$/ {
		in_example_block = 1;
		example_block_temin = $1
		block_max_len=1
		block_index=0
		next
	}

/^\*{4,}[[:space:]]*$/ {
		in_sidebar_block = 1;
		sidebar_block_temin = $1
		block_max_len=1
		block_index=0
		next
	}

/^_{4,}[[:space:]]*$/ {
		in_quote_block = 1;
		quote_block_temin = $1
		block_max_len=1
		block_index=0
		next
	}

/^--[[:space:]]*$/ {
		in_open_block = 1;
		open_block_temin = $1
		block_max_len=1
		block_index=0
		next
	}
# end of block detections


	{ print }


END {

	# to make sure unterminated blocks still get printed
	if (in_literal_block) delimeter_bock_dump(block_lines, block_index,
		block_max_len, style_literal, style_none)
	else if (in_listing_block) delimeter_bock_dump(block_lines, block_index,
		 block_max_len, style_listing, style_none)
	else if (in_example_block) delimeter_bock_dump(block_lines, block_index,
		 block_max_len, style_example, style_none)
	else if (in_sidebar_block) delimeter_bock_dump(block_lines, block_index,
		 block_max_len, style_sidebar, style_none)
	else if (in_quote_block)   delimeter_bock_dump(block_lines, block_index,
		 block_max_len, style_quote, style_none)
	else if (in_open_block)    delimeter_bock_dump(block_lines, block_index,\
		 block_max_len, style_open, style_none)





	printf(style_none) # to make sure the style wont bleed out
}

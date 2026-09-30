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


# block detections
/^\/\/\/\/+[[:space:]]*$/ {
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


	{ print }


END {

		# to make sure unterminated blocks still get printed
		if (in_literal_block)
			delimeter_bock_dump(block_lines, block_index, 
				block_max_len, style_literal, style_none)
		else if (in_listing_block)
			delimeter_bock_dump(block_lines, block_index, 
				block_max_len, style_listing, style_none)
	


		printf(style_none) # to make sure the style wont bleed out
	}

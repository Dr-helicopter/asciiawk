function delimeter_bock_dump(lines, len, width, style, end_style,    i) {
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
		style_quote   = "\033[38;5;7m\033[48;5;0m"
		style_example = "\033[38;5;11m\033[48;5;0m"
		style_sidebar = "\033[38;5;14m\033[48;5;0m"
		style_open    = style_listing

		style["literal"] = style_literal
		style["listing"] = style_listing
		style["open"]    = style_open
		style["quote"]   = style_quote
		style["example"] = style_example
		style["sidebar"] = style_sidebar
	}

	{ # line cleanups
		gsub(/\t/, "    ")
		sub(/[ \t\r]+$/, "")
	}


# block terminated
in_basic_block {
		if (basic_block_temin == $0) {
			if (basic_block_type == "comment") { }
			else delimeter_bock_dump(block_lines, block_index, 
					block_max_len, style[basic_block_type], style_none)
			in_basic_block = 0
			next
		}

		block_lines[block_index++] = $0
			if (length($0) > block_max_len)
				block_max_len = length($0)
		next
	}


# block detections
# each line is a regex and a type assignment
# the assignment only runs when the regex is matched
# and the (||) operatoor makes it fall through the logic
# (simple stuff really)
(/^\/{4,}[[:space:]]*$/	&& basic_block_type = "comment") ||
(/^\.{4,}[[:space:]]*$/	&& basic_block_type = "literal") ||
(/^-{4,}[[:space:]]*$/	&& basic_block_type = "listing") ||
(/^={4,}[[:space:]]*$/	&& basic_block_type = "example") ||
(/^\*{4,}[[:space:]]*$/	&& basic_block_type = "sidebar") ||
(/^_{4,}[[:space:]]*$/ 	&& basic_block_type = "quote")   ||
(/^--[[:space:]]*$/ && basic_block_type = "open"){
		in_basic_block = 1;
		basic_block_temin = $1
		block_max_len=1
		block_index=0
		next
	}


	{ print }


END {

	# to make sure unterminated blocks still get printed
	if (in_basic_block)
		if (basic_block_type == "comment") { }
		else delimeter_bock_dump(block_lines, block_index, 
			block_max_len, style[basic_block_type], style_none)

	printf(style_none) # to make sure the style wont bleed out
}

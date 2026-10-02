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

	style_h1 = "\033[1;35m"   # magenta
	style_h2 = "\033[1;36m"   # cyan
	style_h3 = "\033[1;33m"

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


function pad(s, c, n,   r) {
	r = s ""
	n = n - length(s)
	while (n-- > 0) r = r c
	return r
}

function parse_tabel(data, items_list, x_cel_size,    i, j) {
	sub(/^[ ]*\|/, "", data)
	item_count = split(data, items_list, "|")
	# clean
	for (i=1;i<=item_count;i++) {
		sub(/^[[:space:]]+/, "", items_list[i])
		sub(/[[:space:]]+$/, "", items_list[i])
	}
		
	table_column_count = split(table_first_line, tamp, "|")
	table_row_count = int(item_count/table_column_count)

	delete x_cel_size
	for (i=1;i<=table_row_count * table_column_count;i++) {
		j = i%table_column_count
		j = j == 0 ? table_column_count : j
		if (x_cel_size[j] > length(items_list[i])) {}
		else x_cel_size[j] = length(items_list[i])
	}
}

function table_dump(data,    i, j) {
	sub(/^[ ]*\|/, "", table_first_line)
	parse_tabel(data, items_list, x_cel_len)


	# print the top border
	i=1
	printf("┌%s", pad("", "─", x_cel_len[i])) 
	while (i++<table_column_count) 
		printf("┬%s", pad("", "─", x_cel_len[i])) 
	printf("┐\n") 
	
	# print the top cels
	i=0
	printf("│") 
	while (i++<table_column_count) 
		printf("%s│", pad(items_list[i], " ", x_cel_len[i])) 
	printf("\n")

	j = 1

	while(j<table_row_count) {
		i=1
		printf("├%s", pad("", "─", x_cel_len[i])) 
		while (i++<table_column_count) 
			printf("┼%s", pad("", "─", x_cel_len[i])) 
		printf("┤\n") 

		i=0
		printf("│") 
		while (i++<table_column_count) 
			printf("%s│", 
				pad(items_list[j * table_column_count + i], " ", 
					x_cel_len [i])) 
		printf("\n")
		j++
	}
	
	# print the botom
	i=1
	printf("└%s", pad("", "─", x_cel_len[i])) 
	while (i++<table_column_count) 
		printf("┴%s", pad("", "─", x_cel_len[i])) 
	printf("┘\n") 
}


in_table {
	if (table_termin == $0) {
		in_table = 0
		if (tabel_items != "") table_dump(tabel_items)
		next
	}
	if (length(table_first_line) == 0)
		table_first_line = $0
	tabel_items = tabel_items " " $0
	next
}


/^\|={3,}[[:space:]]*$/ {
	in_table = 1
	table_first_line=""
	table_termin = $1
	tabel_items = ""
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




# this is comment
/^\/\/[^\/]/ { next }
# we just pretend we did'nt see it


# headings
/^={1,6}[[:space:]]+/ {
	if (/^======/) {
		indent=6
		h_style = style_h3
		sub(/[[:space:]]+======$/, "")
	} else if (/^=====/) {
		indent=5
		h_style = style_h3
		sub(/[[:space:]]+=====$/, "")
	} else if (/^====/) {
		indent=4
		h_style = style_h3
		sub(/[[:space:]]+====$/, "")
	} else if (/^===/) {
		indent=3
		h_style = style_h3
		sub(/[[:space:]]+===$/, "")
	} else if (/^==/) {
		indent=2
		h_style = style_h2
		sub(/[[:space:]]+==$/, "")
	} else if (/^=/) {
		indent=0
		h_style = style_h1
		sub(/[[:space:]]+=$/, "")
	}


	sub(/^=+[[:space:]]*/, "")
	printf("%*s%s%s%s\n", indent, "", h_style, $0, style_none)
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

#!/usr/bin/env -S awk -f
function pad(s, c, n, align, r) {
	r = s ""
	n = n - length(s)
	if (align == "r") while(n-->0) r = c r
	else if (align == "c") 	{
		if (n%2) {
			r = r c
			n--
		}
		while(n>0) {
			r = c r c
			n-=2
		}
	}
	else while(n-->0) r = r c 
	return r
}

function delimeter_bock_dump(lines, len, width, style, end_style,    i) {
	block_attribute_list = ""

	width++
	printf("%s %-*s%s\n", style, width," ", end_style)

	for (i=0;i<len;i++)
		printf("%s %-*s%s\n", style, 
		   width,lines[i], end_style)
	printf("%s %-*s%s\n", style, width," ", end_style)

	delete attributes
	delete opts_attributes
}

function trim(s) {
	sub(/^[[:space:]]+/, "", s)
	sub(/[[:space:]]+$/, "", s)
	return s
}

function first_line_slots(line,   s, n, spec, num) {
	s = line
	n = gsub(/\|/, "&", s)        # pipe count, s unchanged
	s = line
	while (match(s, /(^|[ ])([0-9]+(\.[0-9]+)?|\.[0-9]+)[+*][<^>]?(\.[<^>])?[adehlmsv]?\|/)) {
		spec = substr(s, RSTART, RLENGTH)
		sub(/^ /, "", spec)
		if (spec !~ /^\./) {# ".3+" has no column part
			num = int(spec) # int("2.3+") is 2, int("3*") is 3
			if (num > 1) n += num - 1
		}
		s = substr(s, RSTART + RLENGTH - 1)# keep the pipe, resume after the spec
	}
	return n
}


function boarder_draw(start, mid, end,    i, s) {
	s = start pad("", "─", x_cel_len[1])
	for (i=2;i<=table_column_count;i++)
		s = s mid pad("", "─", x_cel_len[i])
	return s end "\n"
}

function row_draw(row,    txt, j, i, s) {
	s = "│"
	for (i=1;i<=table_column_count;i++) {
		j = row * table_column_count + i
		txt = pad(items_list[j], " ", x_cel_len[i],
			cel_halign[table_cel_halign[j]])
		s = s table_cel_styles[j] txt style_none "│"
	}
	return s "\n"
}


BEGIN {
	style_none    ="\033[0m"
	style_literal ="\033[48;5;0m"
	style_listing ="\033[48;5;0m"
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

	
	cel_spec_styles[""] = ""
	cel_spec_styles["a"] = ""
	cel_spec_styles["e"] = "\033[3m"
	cel_spec_styles["h"] = "\033[1m"
	cel_spec_styles["l"] = ""
	cel_spec_styles["s"] = "\033[1m"
	cel_spec_styles["v"] = ""
	cel_spec_styles["m"] = ""
	cel_spec_styles["d"] = ""

	cel_halign["<"] = "l"
	cel_halign["^"] = "c"
	cel_halign[">"] = "r"
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




function parse_tabel(data, items_list, x_cel_size, empty_space_before_c1,
					nxt_cel_style, spec, tmp, i, j, k) {
	item_count = split(data, tmp, "|")

	delete table_cel_styles
	delete table_cel_halign
	# parse_cells
	j=1
	mul=1
	nxt_cel_mul=1
	for (i=1;i<=item_count;i++) {
		if (tmp[i] ~ /[ ]([0-9]+\*)?[<^>]?(\.[<^>])?[adehlmsv]?$/ && 
			i != item_count)
			# edge case, we have no nxt_style when we are at the last pipe

			{ # we have a cell spec at hand
			if 	(tmp[i] ~ /[adehlmsv]$/) { # we have styling spec
				nxt_cel_style= substr(tmp[i], length(tmp[i]), 1)
				tmp[i] = substr(tmp[i], 1,length(tmp[i])-1)
			} if(tmp[i] ~ /(\.[<^>])$/) {
				# tmporarily ignored
				nxt_cel_valign = substr(tmp[i], length(tmp[i]), 1)
				tmp[i] = substr(tmp[i], 1,length(tmp[i])-2)
			} if(tmp[i] ~ /[<^>]$/) {
				nxt_cel_halign = substr(tmp[i], length(tmp[i]), 1)
				tmp[i] = substr(tmp[i], 1,length(tmp[i])-1)
			} if (tmp[i] ~ /[0-9]+\*$/) {
				match(tmp[i], /[0-9]+\*$/)
				nxt_cel_mul = int(substr(tmp[i], RSTART, RLENGTH-1))
				tmp[i] = substr(tmp[i], 1, RSTART - 1)
			} 
		}

		# edge case, if we have a spec before the first pipe
		# and not a first cell without a pipe
		if (i==1 && tmp[i] ~ /^[[:space:]]*$/) {
			j--
			empty_space_before_c1 = 1
		}

		tmp[i] = trim(tmp[i])


		items_list[j] = tmp[i]
		j++
		for (k=2;k<=mul;k++){
			# if we gonna multiply the cells we have to give the specs of
			# the cel we just passed to its multdelete x_cel_size
			items_list[j] = tmp[i]
			table_cel_styles[j] = table_cel_styles[j-1]
			table_cel_halign[j] = table_cel_halign[j-1]
			j++
		}
		table_cel_styles[j] = cel_spec_styles[nxt_cel_style]
		table_cel_halign[j] = nxt_cel_halign

		mul = nxt_cel_mul
		nxt_cel_mul = 1
		nxt_cel_style= "" 
        nxt_cel_halign = "" 
    }
               
       
	# if we havent gotten it from attributes we get it from the first line
    if (!table_column_count)          
        table_column_count = first_line_slots(table_first_line)


    # --j is the number of cells we counted earlier
    table_row_count = int(--j/table_column_count)

    delete x_cel_size
    for (i=1;i<=table_row_count * table_column_count;i++) {
        j = i%table_column_count
        j = j == 0 ? table_column_count : j
        if (x_cel_size[j] > length(items_list[i])) {}
        else x_cel_size[j] = length(items_list[i])
    }
}

function replace(str, pat, with,    i, l) {
	l = length(pat) < length(with) ? length(pat) : length(with)
	for (i=1;i<=l;i++)
		gsub(substr(pat,i,1), substr(with,i,1), str)
	return str
}

function set_attribute(key, val,    tmp, i, c) {
	key = trim(key)
	val = trim(val)
	if (key == "") return

	if (key == "options" || key == "opts") {
		c = split(val, tmp, / *, */)
		for (i=1;i<=c;i++)
			if (tmp[i] != "") opts_attributes[tmp[i]] = 1
	} else
		attributes[key] = val
}

function parse_tabel_block_atrributes(    i, c, in_val, in_string, string_term, key) {
	key=""
	val=""
	in_val = 0 
	in_string = 0
	for(i=1;i<=length(block_attribute_list);i++) {
		c = substr(block_attribute_list,i,1)

		if (in_string == 3) {
			# we are not in a quoted string 
			# we read untill we hit a comma
			if (c == ",") {
				set_attribute(key, val)
				in_string = 0
				in_val = 0
				key = ""
				val = ""
			}
			else 
			val = val c
		} 

		else if (in_string == 2 && c == ",") { 
			# we have finished reading 
			# and are waiting for the next attribute
			set_attribute(key, val)
			in_string = 0
			in_val = 0
			key = ""
			val = ""
		} 

		else if (in_string == 1) {
			# we are reading a string
			if (c == string_term)
				in_string = 2
			else val = val c
		} 

		else if (in_val) {
			# we are not in a string but we are reading a val
			if (c == "\"" || c == "'") {
				in_string = 1
				string_term = c
			} else if ( c ~ /[[:space:]]/) {
			} else {
				val = val c
				in_string = 3
			}
		}
		
		else {
			if (c == "=") {
				in_val = 1
			} else if (c == ","){
				key = ""
			} else {
				key = key c
			}

		}
	}	
	set_attribute(key, val)
}

function render_table(data,    i, j, cols_attibutes, cols_attibute_count) {
	if ("cols" in attributes) {
		cols_attibute_count = split(attributes["cols"], cols_attibutes, ",")
		if (cols_attibute_count == 1)
			table_column_count = int(attributes["cols"])
		else
			table_column_count = cols_attibute_count
	}

	parse_tabel(data, items_list, x_cel_len)

	if (table_row_count == 0) return


	# construct the top border
	tabel_lines[0] = boarder_draw("┌", "┬", "┐")

	# construct the top cells
	tabel_lines[1] = row_draw(0)


	for (i=1;i<table_row_count;i++) {
		tabel_lines[i*2] = boarder_draw("├", "┼", "┤")
		tabel_lines[i*2 +1 ] = row_draw(i)
	}
	
	# construct the botom
	tabel_lines[i*2] = boarder_draw("└", "┴", "┘")

	if (!opts_attributes["noheader"] && tabel_has_empty_seccond_line)
		opts_attributes["header"] = 1

	# restyling the table
	if (opts_attributes["header"]) {
		tabel_lines[0] = replace(tabel_lines[0], "┌┬┐─","╒╤╕═")
		tabel_lines[2] = replace(tabel_lines[2], "├┼┤─└┴┘","╞╪╡═╘╧╛")
	}

	if (opts_attributes["footer"]) {
		tabel_lines[i*2] = replace(tabel_lines[i*2], "└┴┘─","╘╧╛═")
		tabel_lines[i*2-2] = replace(tabel_lines[i*2-2], "├┼┤─┌┬┐","╞╪╡═╒╤╕")
	}

	for (j=0;j<=i*2;j++)
		printf("%s", tabel_lines[j])
}

function dump_table() {
	in_table = 0

	parse_tabel_block_atrributes()
	block_attribute_list = ""

	sub(/ *$/,"",tabel_items)

	if (tabel_items != "") render_table(tabel_items)

	table_column_count = 0
	delete tabel_lines
	delete attributes
	delete opts_attributes
}

in_table {
	if (table_termin == $0) {
		dump_table()
		next
	}

	if (length(table_first_line) == 0)
		table_first_line = $0
	else if (!tabel_read_seccond_line) {
		tabel_has_empty_seccond_line = length($0) == 0
		tabel_read_seccond_line = 1
	}

	tabel_items = tabel_items " " $0
	next
}


/^\|={3,}[[:space:]]*$/ {
	in_table = 1
	table_first_line=""
	table_termin = $1
	tabel_items = ""
	tabel_has_empty_seccond_line = 0
	tabel_read_seccond_line = 0
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

# block attribute
/^\[([[:alnum:]_.#%{,"'].*)?\]$/ {
	sub(/^\[/, "")
	sub(/\]$/, "")


	if (/^%/) { # messy way to deal with shorthand options
		tmp = $0
		sub(/[[:space:]]*,.*$/, "", tmp)
		if (tmp ~ /[[:space:]]/) tmp = ""
		
		block_attribute_list = block_attribute_list "options=\""
		for (i=2;i<=split(tmp, tmp_spilited, "%");i++) {
			block_attribute_list = block_attribute_list tmp_spilited[i] ","
		}
		block_attribute_list = block_attribute_list "\""
		sub(/^%[^,]*,/, "")
	}
	block_attribute_list = block_attribute_list  $0 ","
	next
}

{ print }

END {
	# to make sure unterminated blocks still get printed
	if (in_basic_block)
		if (basic_block_type == "comment") { }
		else delimeter_bock_dump(block_lines, block_index, 
			block_max_len, style[basic_block_type], style_none)
	if (in_table)
		dump_table()

	printf(style_none) # to make sure the style wont bleed out
}

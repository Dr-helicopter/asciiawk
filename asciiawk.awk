#!/usr/bin/env -S gawk -f
# asciiawk 
# written by Dr.Helicopte.  
# october of 2026
# why are you reading this?


# utility functions here VVVVV

# returns the string with no whitespace on eather side
function trim(s) {
	sub(/^[[:space:]]+/, "", s)
	sub(/[[:space:]]+$/, "", s)
	return s
}

# it replaces all instances of all characters of pat in str 
# with charactes of with (and is very ugly)
function replace(str, pat, with,    i, l) {
	l = length(pat) < length(with) ? length(pat) : length(with)
	for (i=1;i<=l;i++) gsub(substr(pat,i,1), substr(with,i,1), str)
	return str
}

# to does a gsub but only on inner elements
function inner_gsub(line, pat, with,   nl, first, last, body) {
	nl = "\n"
	line = substr(line, 1, length(line) - 1)

	if (length(line) < 3) return line nl  # nothing "inner" to touch

	first = substr(line, 1, 1)
	last  = substr(line, length(line), 1)
	body  = substr(line, 2, length(line) - 2)

	gsub(pat, with, body)
	return first body last nl
}

# pads the string s with character c to length n
# align is optional
# align c pads to the middle and align r pads to right
function pad(s, c, n, align,    p, q, i) {
	p = n - length(s)
	q = ""

	for (i = 0; i < p; i++) q = q c

	if (align == "r") return q s
	if (align == "c") return substr(q, 1,int(p / 2)) s substr(q, int(p / 2) + 1)
	else return s q
}

# takes an array and the index to check
function is_string_at(arr, i,    t) {
	if (!(i in arr)) return 0 # undefined: not a string
	t = typeof(arr[i])
	return (t == "string" || t == "strnum")
}
# END of utility functions



# parses block_attribute_list into attributes[] and opts_attributes[]
function parse_block_attributes(    s, entry, key, val, quoted, eq) {
	s = block_attribute_list

	while (s != "") {
		# 1. key = "quoted" or key = 'quoted' (with \ escapes inside)
		if (match(s, /^[^=,]*=[ ]*"([^"\\]|\\.)*"/) ||
		    match(s, /^[^=,]*=[ ]*'([^'\\]|\\.)*'/))
			quoted = 1
		# 2. anything else runs to the next comma (key=value, or a bare word)
		else {
			match(s, /^[^,]*/)
			quoted = 0
		}

		entry = substr(s, 1, RLENGTH)
		# drop the entry, junk after a closing quote, and the comma
		sub(/^[^,]*,?/, "", s)   

		eq = index(entry, "=")
		if (eq == 0) { key = entry; val = "" }
		else {
			key = substr(entry, 1, eq - 1)
			val = substr(entry, eq + 1)
			sub(/^[ ]+/, "", val)
			if (quoted) {
				val = substr(val, 2, length(val) - 2)	# strip the quotes
				val = gensub(/\\(.)/, "\\1", "g", val)	# unescape \" and \\
			}
		}
		set_attribute(key, val, quoted)
	}
}

# helper function for dealing with the cols attribute
function parse_table_cols(s,    n, i, j, mul, idx, tmp, tmp2) {
	# we dont have a list to parse
	if (s ~ /^[0-9]+$/) {
		attributes["cols-count"] = int(s)
		return
	}
	n = split(s, tmp, /[[:space:]]*,[[:space:]]*/)
	
	idx=1
	for (i=1;i<=n;i++){
		j = split(tmp[i], tmp2, /\*/)
		# if we have a multiplier we want to repeat the next action
		# times the multiplier and we want to do it on the second part of the 
		# splited array, otherwise we only do it once
		mul = 1
		if (j > 1){
			mul = int(tmp2[1])
			tmp[i] = tmp2[2]
		}

		if (tmp[i] ~ /[adehlms]$/) {
			table_col_style[idx] = substr(tmp[i], length(tmp[i]))
			sub(/[adehlms]$/, "", tmp[i])
		}
		if (match(tmp[i], /[0-9]+$/)) {
			table_col_width[idx] = substr(tmp[i], RSTART, RLENGTH)
			sub(/[0-9]+$/, "", tmp[i])
		}
		if (tmp[i] ~ /\.[<^>]+$/) {
			table_col_valign[idx] = substr(tmp[i], length(tmp[i]))
			sub(/\.[<^>]+$/, "", tmp[i])
		}

		if (tmp[i] ~ /[<^>]+$/) {
			table_col_halign[idx] = substr(tmp[i], length(tmp[i]))
			sub(/[<^>]+$/, "", tmp[i])
		}
		idx++

		while (--mul>0) {

			table_col_style[idx] = table_col_style[idx-1]
			table_col_width[idx] = table_col_width[idx-1]
			table_col_halign[idx] = table_col_halign[idx-1]
			table_col_valign[idx] = table_col_valign[idx-1]
			idx++

		}
	}

	attributes["cols-count"] = idx - 1
}


# helper function for setting a ablock attribute
# the qouted arguments preserves spaces in *val*
function set_attribute(key, val, quoted,    tmp, i, c) {
	key = trim(key)
	val = quoted ? val : trim(val)
	if (key == "") return

	if (key == "options" || key == "opts") {
		c = split(val, tmp, / *, */)
		for (i=1;i<=c;i++) {
			tmp[i] = trim(tmp[i])
			if (tmp[i] != "") opts_attributes[tmp[i]] = 1
		}
	} else if (key == "cols") parse_table_cols(val)
	else attributes[key] = val
}


# an ugly function that takes a raw cell declaration and parses the next cell's
# specs and returns the cleaned cell contents
function parse_cell_specs(str, idx,    s) {
	s = str
	delete nxt_cell_spec
	# the current cell index and the spec being read is offcet by one
	# so we add one to the index
	idx = idx % table_column_count + 1
	idx = idx == 0 ? table_column_count : idx

	nxt_cell_spec["mul"] = 1
	nxt_cell_spec["hspan"] = 1
	nxt_cell_spec["vspan"] = 1

	nxt_cell_spec["style"] = table_col_style[idx]
	nxt_cell_spec["halign"] = table_col_halign[idx]
	nxt_cell_spec["valign"] = table_col_valign[idx]
	
	# if we dont match this regex, we certainly dont have a spec
	if (s !~ /[ ](([0-9]*\.?[0-9]+\+)|([0-9]+\*))?[<^>]?(\.[<^>])?[adehlmsv]?$/)
		return s

	if 	(s ~ /[adehlmsv]$/) { # styling spec
		nxt_cell_spec["style"] = substr(s, length(s), 1)
		s = substr(s, 1,length(s)-1)
	} 

	if(s ~ /(\.[<^>])$/) { # valign spec
		nxt_cell_spec["valign"] = substr(s, length(s), 1)
		s = substr(s, 1,length(s)-2)
	} if(s ~ /[<^>]$/) { # hspan spec
		nxt_cell_spec["halign"] = substr(s, length(s), 1)
		s = substr(s, 1,length(s)-1)
	} 

	# we either have a multiplier or a span
	if (s ~ /[0-9]+\*$/) { # we have a mul
		match(s, /[0-9]+\*$/)
		nxt_cell_spec["mul"] = int(substr(s, RSTART, RLENGTH-1))
		s = substr(s, 1, RSTART - 1)
	} else if (s ~  /\+$/ ) { # we have a span spec
		# we dont need the '+'
		s = substr(s, 1,length(s)-1)

		if (match(s, /\.[0-9]+$/)) {
			nxt_cell_spec["vspan"] = int(substr(s, RSTART+1))
			s = substr(s, 1, RSTART-1)
		}
		if (match(s, /[0-9]+$/)) {
			nxt_cell_spec["hspan"] = int(substr(s, RSTART))
			s = substr(s, 1, RSTART-1)
		}
	}
	return s
}

function delimited_block_dump(lines, len, width, style, end_style,    i) {
	block_attribute_list = ""

	width++
	printf("%s %-*s%s\n", style, width," ", end_style)

	for (i=0;i<len;i++)
		printf("%s %-*s%s\n", style, 
		   width,lines[i], end_style)
	printf("%s %-*s%s\n\n", style, width," ", end_style)

	delete attributes
	delete opts_attributes
}


# helper function to func the implicit col count in tables
function first_line_slots(line,   s, n, spec, num) {
	s = line
	n = gsub(/\|/, "&", s) # pipe count, s unchanged
	s = line
	while (match(s, /(^|[ ])([0-9]+(\.[0-9]+)?|\.[0-9]+)[+*][<^>]?(\.[<^>])?[adehlmsv]?\|/))
	{
		spec = substr(s, RSTART, RLENGTH)
		sub(/^ /, "", spec)
		if (spec !~ /^\./) { # ".3+" has no column part
			num = int(spec)  # int("2.3+") is 2, int("3*") is 3
			if (num != 1) n += num - 1
		}
		s = substr(s, RSTART + RLENGTH - 1)# keep the pipe, resume after the spec
	}
	return n == 0 ? 1 : n
}



# functions to draw a table
function row_draw(row,    border, txt, j, i, s) {
	for (i=1;i<=table_column_count;i++) {
		# find the index of the current element
		j = row * table_column_count + i

		# get the text and pad it with spaces
		txt = pad(table_cells[j], " ", table_cell_width[i],
			cell_halign[table_cell_halign[j]])

		# decide the border
		border = table_cells_no_back_border[j] == 1 ? J["0000"] : J["1100"]

		# append to the string
		s = s border table_cell_styles[j] txt style_none 	
	}
	return s J["1100"] "\n"
}

function border_draw_top(     i, s, start) {
	# the first cell
	s = J["0101"] pad("", J["0011"], table_cell_width[1])

	for (i=2;i<=table_column_count;i++) {
		# decide what the next cell should start with
		start = table_cells_no_back_border[i] == 1 ? J["0011"] : J["0111"] 

		# append
		s = s start pad("", J["0011"], table_cell_width[i])
	}
	return s J["0110"] "\n"
}

function border_draw_bottom(     i, j, s, start) {
	# the first cell
	s = J["1001"] pad("", J["0011"], table_cell_width[1])

	# find the first cell in the last row
	j = (table_row_count - 1) * table_column_count + 1

	for (i=2;i<=table_column_count;i++) {
		# decide what the next cell should start with
		start = table_cells_no_back_border[++j] == 1 ? J["0011"] : J["1011"] 

		# append
		s = s start pad("", J["0011"], table_cell_width[i])
	}
	return s J["1010"] "\n"
}

function border_draw_mid(row,     i, j, s, border, start) {
	# now this one is a bit more complex

	# find the cell index and decide if weeven have a border 
	j = row * table_column_count + 1
	border = table_cells_no_up_border[j] == 1 ? J["0000"] : J["0011"]

	# make the first cell
	s = J["1101"] pad("", border, table_cell_width[1])

	for (i=2;i<=table_column_count;i++) {
		j++
		border = (table_cells_no_up_border[j] == 1) ? J["0000"] : J["0011"]

		# first look at the cell under the border
		# then look at the cell above and decide the strting character
		if (table_cells_no_back_border[j])
			if (table_cells_no_back_border[j - table_column_count])
				start =  J["0011"]
			else start =  J["1011"]
		else 
			if (table_cells_no_back_border[j - table_column_count])
				start = J["0111"]
			else start = J["1111"] 

		# construct the cell
		s = s start pad("", border, table_cell_width[i])
	}
	s = s J["1110"] "\n"

	# the start character is alot more complicated to determin
	# so insted of making the if/else tower bigger, Im going to let the 
	# neighboring charactes decide
	gsub(" " J["0011"], " " J["0000"], s)
	gsub(" " J["1111"], " " J["1101"], s)
	gsub(" " J["1110"], " " J["1100"], s)
	gsub(J["1101"] " ", J["1100"] " ", s)
	gsub(J["1111"] " ", J["1110"] " ", s)

	return s
}

function render_table(data,    i, j, cols_attibutes, cols_attibute_count, grid) {
	# reder nothing if table is empty
	if (table_row_count == 0) return

	# construct a basic table
	table_lines[0] = border_draw_top()
	table_lines[1] = row_draw(0)
	for (i=1;i<table_row_count;i++) {
		table_lines[i*2] = border_draw_mid(i)
		table_lines[i*2 +1] = row_draw(i)
	}
	table_lines[i*2] = border_draw_bottom()



	if (!opts_attributes["noheader"] && table_has_empty_second_line)
		opts_attributes["header"] = 1


	
	if ("grid" in attributes && attributes["grid"] != "all") {
		# we dont touch it if its grid==all
		if (attributes["grid"] != "rows")
			for (i=1;i<table_row_count;i++)
				table_lines[i*2] = replace(table_lines[i*2], "┼─┴┬┤├","│ ││││")

		if (attributes["grid"] != "cols") {
			gsub("┬","─", table_lines[0])
			for (i=0;i<table_row_count;i++) {
				table_lines[i*2] = inner_gsub(table_lines[i*2], "│", " ")
				table_lines[i*2+1] = inner_gsub(table_lines[i*2+1], "│", " ")
				table_lines[i*2] = inner_gsub(table_lines[i*2], "[^ ]", "─")
			}
			gsub("┴","─", table_lines[i*2])
		}
		# if grid == none or any undefined state, we want to delete it all
	}

	# similar to whats happenning above
	if ("frame" in attributes && attributes["frame"] != "all") {
		if (attributes["frame"] != "ends") {
			table_lines[0] = replace(table_lines[0], "┌┐┬─", "│││ ")
			table_lines[table_row_count*2] = replace(table_lines[table_row_count*2], "└┘┴─", "│││ ")
		} 

		if (attributes["frame"] != "sides") { 
			for (i=0;i<=table_row_count*2;i++) {
				gsub(/^[│]/, " ", table_lines[i])
				gsub(/^[├┌└]/, "─", table_lines[i])
				gsub(/[│]\n/, " \n", table_lines[i])
				gsub(/[┤┐┘]\n/, "─\n", table_lines[i])
			}
		}
	}

	# restyling the table
	if (opts_attributes["header"]) {
		table_lines[0] = replace(table_lines[0], "┌┬┐─","╒╤╕═")
		table_lines[2] = replace(table_lines[2], "├┼┤─└┴┘┬","╞╪╡═╘╧╛╤")
	}

	if (opts_attributes["footer"]) {
		table_lines[table_row_count*2] = replace(table_lines[table_row_count*2], "└┴┘─","╘╧╛═")
		table_lines[table_row_count*2-2]= replace(table_lines[table_row_count*2-2], "├┼┤─┌┬┐┴","╞╪╡═╒╤╕╧")
	}

	for (j=0;j<=table_row_count*2;j++)
		printf("%s", table_lines[j])
}
# END of table draw functoins


function parse_table(data, x_cell_size,    tmp, i, j, k, w, v,
					 back_flag, up_flag) {
	delete table_cells
	delete table_cells_no_back_border
	delete table_cells_no_up_border
	delete table_cell_styles
	delete table_cell_halign

	# get the table_column_count
	if (attributes["cols-count"])
		table_column_count = attributes["cols-count"]
	else
        table_column_count = first_line_slots(table_first_line)


	# parse_cells
	j=1
	mul=1
	cur_cell_style = "" 
	cur_cell_halign = ""
	cur_cell_hspan = 1
	cur_cell_vspan = 1

	item_count = split(data, tmp, "|")
	for (i=1;i<=item_count;i++) {
		# edge case, we have no nxt_style when we are at the last pipe
		if (item_count!=i) 
			tmp[i] = parse_cell_specs(tmp[i],
				(i==1 && tmp[i] ~ /^[[:space:]]*$/) ? 0 : j) # 0 gives column 1
		
		# edge case, if we have a spec before the first pipe
		# and not a first cell without a pipe
		if (i==1 && tmp[i] ~ /^[[:space:]]*$/)
			j--

		tmp[i] = trim(tmp[i])
		
		# we dont want to write over filled cells
		while(is_string_at(table_cells,j)) j++

		if (cur_cell_hspan>1 || cur_cell_vspan>1) { # cel is a span
			v = j

			up_flag = 0
			for (w=1;w<=cur_cell_vspan;w++) {
				back_flag = 0
				for (k=1;k<=cur_cell_hspan;k++) {
					if (is_string_at(table_cells, v)) { # collision ! ABORT !
						k = cur_cell_hspan
						w = cur_cell_vspan
					}

					if (v % table_column_count == 0) { # end of row! ABORT !
						k = cur_cell_hspan
					}

					table_cells[v] = ""
					table_cell_styles[v] = cell_spec_styles[cur_cell_style]
					table_cell_halign[v] = cur_cell_halign
					table_cells_no_back_border[v] = back_flag
					table_cells_no_up_border[v] = up_flag

					back_flag = 1
					v++
				}
				up_flag = 1
				v = j + w * table_column_count
			}

			if (cur_cell_halign == ">"){
				t = j%table_column_count + cur_cell_halign
	table_cells[j + (t > table_column_count ? table_column_count : t)] = tmp[i]
			} else 
			table_cells[j] = tmp[i]
			j++

		} else {
			for (k=1;k<=mul;k++){
				# we dont want to write over filled cells
				while(is_string_at(table_cells,j)) j++

				# if we gonna multiply the cells we have to give the specs of
				# the cel we just passed to its mult
				table_cells[j] = tmp[i]
				table_cell_styles[j] = cell_spec_styles[cur_cell_style]
				table_cell_halign[j] = cur_cell_halign
				j++
			}
		}
		cur_cell_style = nxt_cell_spec["style"]
		cur_cell_halign = nxt_cell_spec["halign"]
		cur_cell_hspan = nxt_cell_spec["hspan"]
		cur_cell_vspan = nxt_cell_spec["vspan"]
	
		mul = nxt_cell_spec["mul"]
    }

	# we count until we are out of filled
	while(is_string_at(table_cells,j)) j++

    # j-1 is the number of cells we counted earlier
    table_row_count = table_column_count != 0 ? int(--j/table_column_count) : 0

    delete x_cell_size
    for (i=1;i<=table_row_count * table_column_count;i++) {
        j = i%table_column_count
        j = j == 0 ? table_column_count : j
        if (x_cell_size[j] < length(table_cells[i])) 
        	x_cell_size[j] = length(table_cells[i])
    }

	delete table_col_valign
	delete table_col_halign
	delete table_col_style
	delete table_col_width
}

function dump_table() {
	in_table = 0

	parse_block_attributes()
	block_attribute_list = ""

	if ("title" in attributes) {
		printf("%s.", style_ti)
		if ("caption" in attributes)
			printf ("%s", attributes["caption"])
		else 
			printf ("Table %d. ", ++table_counter)
		
		printf("%s\n",attributes["title"] style_none)
	}

	sub(/ *$/,"",table_items)
	if (table_items != "") {
		parse_table(table_items, table_cell_width)
		render_table(table_items)
		printf("\n")
	}

	table_column_count = 0
	delete table_lines
	delete attributes
	delete opts_attributes
}


function dump_paragraph() {
	if (paragraph_text != "")
		printf("%s", format_inline(paragraph_text))
	paragraph_text = ""
	in_paragraph = 0
}



function inline_restore(bold, italic,    s) {
    s = ""
    if (bold) s = s "\033[1m"
	if (italic) s = s "\033[3m"
    return s
}

function format_inline(text, bold, italic,    out, i, j, n, c, prev, nxt, inner, found) {
    out = ""
    n = length(text)

    for (i = 1; i <= n; ) {
        c = substr(text, i, 1)
        prev = (i > 1 ? substr(text, i - 1, 1) : "")
        nxt = (i < n ? substr(text, i + 1, 1) : "")
        found = 0

        # monospace: content is literal, so don't parse its contents.
        if (c == "`" && nxt != "`" && prev != "`") {
            for (j = i + 1; j <= n; j++) {
                if (substr(text, j, 1) == "`" &&
                    substr(text, j - 1, 1) != "`" &&
                    substr(text, j + 1, 1) != "`" &&
                    j > i + 1) {
                    inner = substr(text, i + 1, j - i - 1)
                    out = out style_literal inner style_none \
                        inline_restore(bold, italic)
                    i = j + 1
                    found = 1
                    break
                }
            }

            if (found)
                continue
        }

        # Bold and italic: avoid treating markers inside words as delimiters.
        if ((c == "*" || c == "_") &&
            !(prev ~ /[[:alnum:]]/)) {
            for (j = i + 1; j <= n; j++) {
                if (substr(text, j, 1) == c &&
                    j > i + 1 &&
                    !(substr(text, j + 1, 1) ~ /[[:alnum:]]/)) {
                    inner = substr(text, i + 1, j - i - 1)

                    if (c == "*")
                        out = out "\033[1m" \
                            format_inline(inner, 1, italic) \
                            style_none inline_restore(bold, italic)
                    else
                        out = out "\033[3m" \
                            format_inline(inner, bold, 1) \
                            style_none inline_restore(bold, italic)

                    i = j + 1
                    found = 1
                    break
                }
            }

            if (found)
                continue
        }

        # No valid delimiter pair: preserve the character.
        out = out c
        i++
    }

    return out
}


BEGIN { # mostly variable assignments
	style_none    ="\033[0m"
	style_literal ="\033[48;5;0m"
	style_listing ="\033[48;5;0m"
	style_quote   = "\033[38;5;7m\033[48;5;0m"
	style_example = "\033[33;40m"
	style_sidebar = "\033[38;5;14m\033[48;5;0m"
	style_open    = style_listing

	style_h1 = "\033[1;35m"   # megenta
	style_h2 = "\033[1;36m"   # cyan
	style_h3 = "\033[1;33m"	  # yellow

	style_ti = "\033[1;33m"

	style_li = "\033[1;32m"

	style_admonition = "\033[1;30;43m"	# yellow

	style["literal"] = style_literal
	style["listing"] = style_listing
	style["open"]    = style_open
	style["quote"]   = style_quote
	style["example"] = style_example
	style["sidebar"] = style_sidebar

	
	cell_spec_styles[""] = ""
	cell_spec_styles["a"] = ""
	cell_spec_styles["e"] = "\033[3m"
	cell_spec_styles["h"] = "\033[1m"
	cell_spec_styles["l"] = ""
	cell_spec_styles["s"] = "\033[1m"
	cell_spec_styles["v"] = ""
	cell_spec_styles["m"] = ""
	cell_spec_styles["d"] = ""

	cell_halign["<"] = "l"
	cell_halign["^"] = "c"
	cell_halign[">"] = "r"

	J["0000"]=" "; J["1000"]="│"; J["0100"]="│"; J["1100"]="│"
	J["0010"]="─"; J["0001"]="─"; J["0011"]="─"
	J["0101"]="┌"; J["0110"]="┐"; J["1001"]="└"; J["1010"]="┘"
	J["1101"]="├"; J["1110"]="┤"; J["0111"]="┬"; J["1011"]="┴"; J["1111"]="┼"

	paragraph_width = 80
}

{ # line cleanups
	gsub(/\t/, "    ")
	sub(/[ \t\r]+$/, "")
}


# block terminated
in_basic_block {
	if (basic_block_term == $0) {
		if (basic_block_type == "comment") { }
		else delimited_block_dump(block_lines, block_index, 
				block_max_len, style[basic_block_type], style_none)
		in_basic_block = 0
		next
	}

	block_lines[block_index++] = $0
		if (length($0) > block_max_len)
			block_max_len = length($0)
	next
}

in_table {
	if (table_term == $0) {
		dump_table()
		next
	}

	if (length(table_first_line) == 0)
		table_first_line = $0
	else if (!table_read_second_line) {
		table_has_empty_second_line = length($0) == 0
		table_read_second_line = 1
	}

	table_items = table_items " " $0
	next
}


/^\|={3,}[[:space:]]*$/ {
	in_table = 1
	table_first_line=""
	table_term = $1
	table_items = ""
	table_has_empty_second_line = 0
	table_read_second_line = 0

	if (in_list)
		terminate_list()
	terminate_admonition()
	dump_paragraph()
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
	basic_block_term = $1
	block_max_len=1
	block_index=0

	if (in_list) {
		terminate_list()
		printf "\n"
	}
	terminate_admonition()
	dump_paragraph()
	next
}

# this is comment
/^\/\/[^\/]/ || /^\/\/$/ { 
	if (list_termable) terminate_list()
	next 
}
# we just pretend we did'nt see it


# block attribute
/^\[([[:alnum:]_.#%{,"'].*)?\]$/ {
	if (list_termable) terminate_list()
	terminate_admonition()
	sub(/^\[/, "")
	sub(/\]$/, "")


	if (/^%/) { # messy way to deal with shorthand options
		tmp = $0
		sub(/[[:space:]]*,.*$/, "", tmp)
		if (tmp ~ /[[:space:]]/) tmp = ""
		
		block_attribute_list = block_attribute_list "options=\""
		for (i=2;i<=split(tmp, tmp_parts, "%");i++) {
			block_attribute_list = block_attribute_list tmp_parts[i] ","
		}
		block_attribute_list = block_attribute_list "\","
		sub(/^%[^,]*,/, "")
	}
	block_attribute_list = block_attribute_list  $0 ","
	next
}



function print_ordered_list(indent, item){
	# if we are going back down from high indent
	# we want to delete the indents higher then current indent
	if (list_last_indent_level > indent)
		for (i=indent+1;i<=list_last_indent_level;i++)
			ordered_list_count[i]=0
	
	list_last_indent_level = indent
	ordered_list_count[indent]++
	printf("\n%*s%s%d%s %s ", indent, "", style_li,
		   ordered_list_count[indent], style_none, item)
}

function terminate_list() {
	printf("\n")
	in_list = 0
	list_termable = 0
	list_last_indent_level = 0
	added_indent = 0
	list_indent_stack_size = 0
	delete list_indent_stack
	delete ordered_list_count
}


# could be part of the next condition below, but i think this is cleaner.
in_list {
	if (!(/^\** / || /^\- / || /^\.* / || /^[ ]*$/ || /^.+::+($|[ ])/) && 
			list_termable) {
		terminate_list()
		printf("\n")
	}
}

((/^[ ]*\*+ / || /[ ]*^\- / || /[ ]*^\.+ / || /^.+::+($|[ ])/) && 
		!in_paragraph && !in_admonition) || in_list {
	$0 = trim($0)

	if ($0 == "") {
		list_termable = 1
		next
	} else {

		# handle the title
		parse_block_attributes()
		block_attribute_list = ""
		if ("title" in attributes) 
			printf("%s.%s\n", style_ti, attributes["title"] style_none)
		delete attributes
		delete opts_attributes

		in_list = 1
		list_termable = 0
		
		# normal lists 
		if (match($0, /^(\*+|\.+|[-]) /)) {
			list_item_marker = substr($0, 0, RLENGTH)
			sub(/^(\*+|\.+|[-]) */, "")
			list_item_text = $0


			if (list_item_marker in list_indent_stack)
				indent = list_indent_stack[list_item_marker]
			else {
				indent = list_indent_stack_size++
			 	list_indent_stack[list_item_marker] = indent
			}
			if (list_item_marker ~ /^\./) 
				print_ordered_list(indent, list_item_text)
			else 
				printf("\n%*s%s*%s %s ",  indent, "", 
				   style_li, style_none, list_item_text)


		# descrion list
		} else if (match($0, /^.+::+($|[ ])/)){
			# it cuts off the description first
			# then it seperates the descrion indent from the rest
			match($0, /^.([^:]|:[^:])*::+/)
			list_item_description = trim(substr($0, RLENGTH+1))
			match(substr($0, 0, RLENGTH), /.:*$/)
			list_item_marker = substr($0, RSTART+1, RLENGTH)
			list_item_term = trim(substr($0, 0 , RSTART))


			if (list_item_marker in list_indent_stack)
				indent = list_indent_stack[list_item_marker]
			else {
				indent = list_indent_stack_size++
			 	list_indent_stack[list_item_marker] = indent
			}

			printf("\n%*s%s%s:%s ",  indent, "", 
			   style_li, list_item_term, style_none)
			printf("\n%*s%s ",  indent+1, "", list_item_description)

		} else printf("%s ", $0)
		next
	}
}

function terminate_admonition() {
	if (in_admonition) {
		in_admonition = 0
		printf "\n"
	}
}

in_admonition {
	if ($0 ~ /^[[:space:]]*$/) {
		in_admonition = 0
		printf "\n"
	} else 
		printf("%s ", trim($0))
	next
}

(/^(NOTE|TIP|IMPORTANT|WARNING|CAUTION): ./) && !in_paragraph {
	in_admonition = 1
	printf "\n"

	parse_block_attributes()
	block_attribute_list = ""
	if ("title" in attributes) 
		printf("%s.%s\n", style_ti, attributes["title"] style_none)
	delete attributes
	delete opts_attributes


	match($0, /^[^:]*:/)
	
	printf("%s%s %s\n", style_admonition, substr($0, 1, RLENGTH), style_none)
	sub(/^[^:]*:[[:space:]]*/, "")
	printf("   %s ", trim($0))
	next
} 

# hrules
/^'''+[[:space:]]*$/ {
	printf("%s\n\n", pad("", "─", paragraph_width))
	next
}

/^<<<[[:space:]]*$/ {
	printf("%s\n\n", pad("", "═", paragraph_width))
	next
}

# title 
/^\.{1,2}[^ \.].*/ {
	$0 = substr($0,2)
	gsub(/"/, "\\\"", $0)
	block_attribute_list = block_attribute_list "title=\"" trim($0) "\","
	next
}

# headings
/^={1,6}[[:space:]]+/ {
	dump_paragraph()

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
	printf("%*s%s%s%s\n\n", indent, "", h_style, $0, style_none)
	next
}

{
	$0 = trim($0)
	if ($0 == "") {
		dump_paragraph()
		next
	}
	paragraph_text = paragraph_text $0 "\n"
	in_paragraph = 1
	next
}



END {
	# to make sure unterminated blocks still get printed
	if (in_basic_block)
		if (basic_block_type == "comment") { }
		else delimited_block_dump(block_lines, block_index, 
			block_max_len, style[basic_block_type], style_none)
	if (in_table)
		dump_table()
	if (paragraph_text != "") 
		dump_paragraph()

	printf(style_none "\n") # to make sure the style wont bleed out
}

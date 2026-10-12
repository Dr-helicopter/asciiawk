#!/usr/bin/env -S awk -f
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

# to does a Gsub but only on inner elements
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

# AI generated function
function is_string_at(arr, i,    t) {
	if (!(i in arr)) return 0          # undefined: not a string
	t = typeof(arr[i])
	return (t == "string" || t == "strnum")
}
# END of utility functions




# an ugly function that takes a raw cell declaration and parses the next cell's
# specs and returns the cleaned cell contents
function parse_cel_specs(str,    s) {
	s = str
	delete nxt_cel_spec
	nxt_cel_spec["mul"] = 1
	nxt_cel_spec["hspan"] = 1
	nxt_cel_spec["vspan"] = 1
	nxt_cel_spec["style"] = ""
	nxt_cel_spec["halign"] = ""
	nxt_cel_spec["valign"] = ""
	
	# if we dont match this regex, we certainly dont have a spec
	if (s !~ /[ ](([0-9]*\.?[0-9]+\+)|([0-9]+\*))?[<^>]?(\.[<^>])?[adehlmsv]?$/)
		return s

	if 	(s ~ /[adehlmsv]$/) { # styling spec
		nxt_cel_spec["style"] = substr(s, length(s), 1)
		s = substr(s, 1,length(s)-1)
	} 

	if(s ~ /(\.[<^>])$/) { # valign spec
		nxt_cel_spec["valign"] = substr(s, length(s), 1)
		s = substr(s, 1,length(s)-2)
	} if(s ~ /[<^>]$/) { # hspan spec
		nxt_cel_spec["halign"] = substr(s, length(s), 1)
		s = substr(s, 1,length(s)-1)
	} 

	# we either have a multiplier or a span
	if (s ~ /[0-9]+\*$/) { # we have a mul
		match(s, /[0-9]+\*$/)
		nxt_cel_spec["mul"] = int(substr(s, RSTART, RLENGTH-1))
		s = substr(s, 1, RSTART - 1)
	} else if (s ~  /\+$/ ) { # we have a span spec
		# we dont need the '+'
		s = substr(s, 1,length(s)-1)

		if (match(s, /\.[0-9]+$/)) {
			nxt_cel_spec["vspan"] = int(substr(s, RSTART+1))
			s = substr(s, 1, RSTART-1)
		}
		if (match(s, /[0-9]+$/)) {
			nxt_cel_spec["hspan"] = int(substr(s, RSTART))
			s = substr(s, 1, RSTART-1)
		}
	}
	return s
}




function delimeted_bock_dump(lines, len, width, style, end_style,    i) {
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


function first_line_slots(line,   s, n, spec, num) {
	s = line
	n = gsub(/\|/, "&", s)        # pipe count, s unchanged
	s = line
	while (match(s, /(^|[ ])([0-9]+(\.[0-9]+)?|\.[0-9]+)[+*][<^>]?(\.[<^>])?[adehlmsv]?\|/))
	{
		spec = substr(s, RSTART, RLENGTH)
		sub(/^ /, "", spec)
		if (spec !~ /^\./) {# ".3+" has no column part
			num = int(spec) # int("2.3+") is 2, int("3*") is 3
			if (num != 1) n += num - 1
		}
		s = substr(s, RSTART + RLENGTH - 1)# keep the pipe, resume after the spec
	}
	return n == 0 ? 1 : n
}



BEGIN {
	style_none    ="\033[0m"
	style_literal ="\033[48;5;0m"
	style_listing ="\033[48;5;0m"
	style_quote   = "\033[38;5;7m\033[48;5;0m"
	style_example = "\033[38;5;11m\033[48;5;0m"
	style_sidebar = "\033[38;5;14m\033[48;5;0m"
	style_open    = style_listing

	style_h1 = "\033[1;35m"   # megenta
	style_h2 = "\033[1;36m"   # cyan
	style_h3 = "\033[1;33m"	  # yellow

	style_ti = "\033[1;33m"

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

	J["0000"]=" "; J["1000"]="│"; J["0100"]="│"; J["1100"]="│"
	J["0010"]="─"; J["0001"]="─"; J["0011"]="─"
	J["0101"]="┌"; J["0110"]="┐"; J["1001"]="└"; J["1010"]="┘"
	J["1101"]="├"; J["1110"]="┤"; J["0111"]="┬"; J["1011"]="┴"; J["1111"]="┼"
}

{ # line cleanups
	gsub(/\t/, "    ")
	sub(/[ \t\r]+$/, "")
}


# block terminated
in_basic_block {
	if (basic_block_temin == $0) {
		if (basic_block_type == "comment") { }
		else delimeted_bock_dump(block_lines, block_index, 
				block_max_len, style[basic_block_type], style_none)
		in_basic_block = 0
		next
	}

	block_lines[block_index++] = $0
		if (length($0) > block_max_len)
			block_max_len = length($0)
	next
}


function row_draw(row,    border, txt, j, i, s) {
	s = ""
	for (i=1;i<=table_column_count;i++) {
		j = row * table_column_count + i
		txt = pad(items_list[j], " ", table_cel_width[i],
			cel_halign[table_cel_halign[j]])
		border = table_cels_no_back_border[j] == 1 ? " " : "│"
		s = s border table_cel_styles[j] txt style_none 	
	}
	return s "│\n"
}

function boarder_draw(start, mid, end, row,   i, s) {
	j = row * table_column_count + 1
	border = table_cels_no_up_border[j] == 1 ? " " : "─"

	s = start pad("", border, table_cel_width[1])
	for (i=2;i<=table_column_count;i++) {
		j++
		border = table_cels_no_up_border[j] == 1 ? " " : "─"
		s = s mid pad("", border, table_cel_width[i])
	}
	return s end "\n"
}


function boarder_draw_top(     i, s, border, start) {
	border = J["0011"]
	s = J["0101"] pad("", border, table_cel_width[1])

	for (i=2;i<=table_column_count;i++) {
		start = table_cels_no_back_border[i] == 1 ? J["0011"] : J["0111"] 
		s = s start pad("", border, table_cel_width[i])
	}
	return s J["0110"] "\n"
}

function boarder_draw_bottom(     i, j, s, border, start) {
	border = J["0011"]
	s = J["1001"] pad("", border, table_cel_width[1])

	j = (table_row_count - 1) * table_column_count + 1
	for (i=2;i<=table_column_count;i++) {
		start = table_cels_no_back_border[++j] == 1 ? J["0011"] : J["1011"] 
		s = s start pad("", border, table_cel_width[i])
	}
	return s J["1010"] "\n"
}

function boarder_draw_mid(row,     i, j, s, border, start) {
	j = row * table_column_count + 1
	border = table_cels_no_up_border[j] == 1 ? " " : "─"

	s = J["1101"] pad("", border, table_cel_width[1])
	for (i=2;i<=table_column_count;i++) {
		j++
		border = (table_cels_no_up_border[j] == 1) ? " " : "─"
		if (table_cels_no_back_border[j] == 1) {
			if (table_cels_no_back_border[j - table_column_count] == 1)
				start =  J["0011"]
			else start =  J["1011"]

		} else {
			if (table_cels_no_back_border[j - table_column_count] == 1)
				start = J["0111"]
			else start = J["1111"] 
		}
		s = s start pad("", border, table_cel_width[i])
	}
	return s J["1110"] "\n"
}


function parse_tabel(data, table_cels, x_cel_size,    tmp, i, j, k, w, v,
					 back_flag, up_flag) {
	delete table_cels
	delete table_cels_no_back_border
	delete table_cels_no_up_border
	delete table_cel_styles
	delete table_cel_halign

	# if we havent gotten it from attributes we get it from the first line
    if (!table_column_count)          
        table_column_count = first_line_slots(table_first_line)


	# parse_cells
	j=1
	mul=1
	cur_cel_style = "" 
	cur_cel_halign = ""
	cur_cel_hspan = 1
	cur_cel_vspan = 1

	item_count = split(data, tmp, "|")
	for (i=1;i<=item_count;i++) {
		# edge case, we have no nxt_style when we are at the last pipe
		if (item_count!=i) 
			tmp[i] = parse_cel_specs(tmp[i])

		
		# edge case, if we have a spec before the first pipe
		# and not a first cell without a pipe
		if (i==1 && tmp[i] ~ /^[[:space:]]*$/)
			j--

		tmp[i] = trim(tmp[i])
		
		# we dont want to write over filled cells
		while(is_string_at(table_cels,j)) j++

		if (cur_cel_hspan>1 || cur_cel_vspan>1) { # cel is a span
			v = j

			up_flag = 0
			for (w=1;w<=cur_cel_vspan;w++) {
				back_flag = 0
				for (k=1;k<=cur_cel_hspan;k++) {
					if (is_string_at(table_cels, v)) { # collision ! ABORT !
						k = cur_cel_hspan
						w = cur_cel_vspan
					}

					if (v % table_column_count == 0) { # end of row! ABORT !
						k = cur_cel_hspan
					}

					table_cels[v] = ""
					table_cel_styles[v] = cel_spec_styles[cur_cel_style]
					table_cel_halign[v] = cur_cel_halign
					table_cels_no_back_border[v] = back_flag
					table_cels_no_up_border[v] = up_flag

					back_flag = 1
					v++
				}
				up_flag = 1
				v = j + w * table_column_count
			}

			if (cur_cel_halign == ">"){
				t = j%table_column_count + cur_cel_halign
	table_cels[j + (t > table_column_count ? table_column_count : t)] = tmp[i]
			} else 
			table_cels[j] = tmp[i]
			j++

		} else {
			for (k=1;k<=mul;k++){
				# we dont want to write over filled cells
				while(is_string_at(table_cels,j)) j++

				# if we gonna multiply the cells we have to give the specs of
				# the cel we just passed to its mult
				table_cels[j] = tmp[i]
				table_cel_styles[j] = cel_spec_styles[cur_cel_style]
				table_cel_halign[j] = cur_cel_halign
				j++
			}
		}
		cur_cel_style = nxt_cel_spec["style"]
		cur_cel_halign = nxt_cel_spec["halign"]
		cur_cel_hspan = nxt_cel_spec["hspan"]
		cur_cel_vspan = nxt_cel_spec["vspan"]
	
		mul = nxt_cel_spec["mul"]
    }

	# we count until we are out of filled
	while(is_string_at(table_cels,j)) j++

    # j-1 is the number of cells we counted earlier
    table_row_count = table_column_count != 0 ? int(--j/table_column_count) : 0

    delete x_cel_size
    for (i=1;i<=table_row_count * table_column_count;i++) {
        j = i%table_column_count
        j = j == 0 ? table_column_count : j
        if (x_cel_size[j] < length(table_cels[i])) 
        	x_cel_size[j] = length(table_cels[i])
    }
}

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

		if (in_escape) {
			val = val c
			in_escape = 0
		}
		else if (in_string == 3) {
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
			set_attribute(key, val, 1)
			in_string = 0
			in_val = 0
			key = ""
			val = ""
		} else if (in_string == 2){
			# do nothing if string isnt ended
		} 
		else if (in_string == 1) {
			# we are reading a string
			if (c == "\\") in_escape = 1
			else if (c == string_term)
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

# helper for frame=ends
function frame_ends_style(s,    t) {
	t = s
	return t
}

function render_table(data,    i, j, cols_attibutes, cols_attibute_count, grid) {
	if ("cols" in attributes) {
		cols_attibute_count = split(attributes["cols"], cols_attibutes, ",")
		if (cols_attibute_count == 1)
			table_column_count = int(attributes["cols"])
		else
			table_column_count = cols_attibute_count
	}

	parse_tabel(data, items_list, table_cel_width)

	if (table_row_count == 0) return

	# determin_grid_type
	if ("grid" in attributes) {
		grid = "r"
	} else grid = "a"

	# construct the top border
	tabel_lines[0] = boarder_draw_top()

	# construct the top cells
	tabel_lines[1] = row_draw(0)

	for (i=1;i<table_row_count;i++) {
		tabel_lines[i*2] = boarder_draw_mid(i)
		tabel_lines[i*2 +1] = row_draw(i)
	}
	
	# construct the botom
	tabel_lines[i*2] = boarder_draw_bottom()

	if (!opts_attributes["noheader"] && tabel_has_empty_seccond_line)
		opts_attributes["header"] = 1

	# fixinng table border gaps
	for (i=0;i<table_row_count;i++) {
		gsub(/├[ ]/, "│ ", tabel_lines[i*2])
		gsub(/[ ]┤/, " │", tabel_lines[i*2])
		gsub(/[ ]┼/, " ├", tabel_lines[i*2])
		gsub(/┼[ ]/, "┤ ", tabel_lines[i*2])
		gsub(/├[ ]/, "│ ", tabel_lines[i*2])
		gsub(/[ ]─/, "  ", tabel_lines[i*2])
	}
	

	
	if ("grid" in attributes && attributes["grid"] != "all") {
		# we dont touch it if its grid==all
		if (attributes["grid"] != "rows")
			for (i=1;i<table_row_count;i++)
				tabel_lines[i*2] = replace(tabel_lines[i*2], "┼─┴┬┤├","│ ││││")

		if (attributes["grid"] != "cols") {
			gsub("┬","─", tabel_lines[0])
			for (i=0;i<table_row_count*2;i++) {
				tabel_lines[i] = inner_gsub(tabel_lines[i], "│", " ")
				tabel_lines[i] = inner_gsub(tabel_lines[i], "┤", "─")
				tabel_lines[i] = inner_gsub(tabel_lines[i], "├", "─")
				gsub(/┼/, "─", tabel_lines[i])
			}
			gsub("┴","─", tabel_lines[i])
		}
		# if grid == none or any undefined state we want to delete it all
	}

	# similar to whats happenning above
	if ("frame" in attributes && attributes["frame"] != "all") {
		if (attributes["frame"] != "ends") {
			tabel_lines[0] = replace(tabel_lines[0], "┌┐┬─", "│││ ")
			tabel_lines[table_row_count*2] = replace(tabel_lines[table_row_count*2], "└┘┴─", "│││ ")
		} 

		if (attributes["frame"] != "sides") { 
			for (i=0;i<=table_row_count*2;i++) {
				gsub(/^[│]/, " ", tabel_lines[i])
				gsub(/^[├┌└]/, "─", tabel_lines[i])
				gsub(/[│]\n/, " \n", tabel_lines[i])
				gsub(/[┤┐┘]\n/, "─\n", tabel_lines[i])
			}
		}
	}

	# restyling the table
	if (opts_attributes["header"]) {
		tabel_lines[0] = replace(tabel_lines[0], "┌┬┐─","╒╤╕═")
		tabel_lines[2] = replace(tabel_lines[2], "├┼┤─└┴┘┬","╞╪╡═╘╧╛╤")
	}

	if (opts_attributes["footer"]) {
		tabel_lines[table_row_count*2] = replace(tabel_lines[table_row_count*2], "└┴┘─","╘╧╛═")
		tabel_lines[table_row_count*2-2]= replace(tabel_lines[table_row_count*2-2], "├┼┤─┌┬┐┴","╞╪╡═╒╤╕╧")
	}

	for (j=0;j<=table_row_count*2;j++)
		printf("%s", tabel_lines[j])
}

function dump_table() {
	in_table = 0

	parse_tabel_block_atrributes()
	block_attribute_list = ""

	sub(/ *$/,"",tabel_items)

	if ("title" in attributes) {
		printf("%s.", style_ti)
		if ("caption" in attributes)
			printf ("%s", attributes["caption"])
		else 
			printf ("Table %d. ", ++table_counter)
		
		printf("%s\n",attributes["title"] style_none)
	}

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
		block_attribute_list = block_attribute_list "\","
		sub(/^%[^,]*,/, "")
	}
	block_attribute_list = block_attribute_list  $0 ","
	next
}

# title 
/^\.{1,2}[^ \.].*/ {
	$0 = substr($0,2)
	gsub(/"/, "\\\"", $0)
	block_attribute_list = block_attribute_list "title=\"" trim($0) "\","
	next
}


{ print }

END {
	# to make sure unterminated blocks still get printed
	if (in_basic_block)
		if (basic_block_type == "comment") { }
		else delimeted_bock_dump(block_lines, block_index, 
			block_max_len, style[basic_block_type], style_none)
	if (in_table)
		dump_table()

	printf(style_none) # to make sure the style wont bleed out
}

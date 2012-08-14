%option noyywrap
%option noinput
%option nounput
%option yylineno

%{
/*
 * potool is a program aiding editing of po files
 * Copyright (C) 1999-2002 Zbigniew Chyla
 * Copyright (C) 2000-2012 Marcin Owsiany <porridge@debian.org>
 *
 * see LICENSE for licensing info
 */
#include <stdio.h>
#include <string.h>
#include <glib.h>
#include "i18n.h"
#include "po-gram.h"
#include "po.tab.h"

static YY_BUFFER_STATE buf_state = (YY_BUFFER_STATE) 0;
static FILE *buf_file = NULL;

void
po_scan_open_file (char *fn)
{
	if (buf_state != (YY_BUFFER_STATE) 0) {
		g_error (_("Trying to scan two files!"));
	}
	if ((buf_file = fopen (fn, "r")) == NULL) {
		g_error (_("Can't open input file: %s\n"), fn);
	}
	buf_state = yy_create_buffer (buf_file, YY_BUF_SIZE);
	yy_switch_to_buffer (buf_state);
}

void po_scan_close_file (void)
{
	if (buf_state == (YY_BUFFER_STATE) 0) {
		g_error (_("Can't delete input buffer!"));
	}
	buf_state = NULL;
	buf_file = NULL;
	yy_delete_buffer (buf_state);
}


%}

%%
"msgctxt"           { return MSGCTXT; }
"msgid"             { return MSGID; }
"msgid_plural"      { return MSGID_PLURAL; }
"#| msgctxt"        { return PREVIOUS_MSGCTXT; }
"#| msgid"          { return PREVIOUS_MSGID; }
"#| msgid_plural"   { return PREVIOUS_MSGID_PLURAL; }
"msgstr"            { return MSGSTR; }
"["[0-9]*"]"          {
	polval.str_val = g_strndup (yytext + 1, yyleng - 2);
	return MSGSTR_X;
}
\"(\\.|[^\\"])*\"   {
	polval.str_val = g_strndup (yytext + 1, yyleng - 2);
	return STRING;
}
"#~ msgctxt"           { return OBSOLETE_MSGCTXT; }
"#~ msgid"             { return OBSOLETE_MSGID; }
"#~ msgid_plural"      { return OBSOLETE_MSGID_PLURAL; }
"#~| msgctxt"          { return OBSOLETE_PREVIOUS_MSGCTXT; }
"#~| msgid"            { return OBSOLETE_PREVIOUS_MSGID; }
"#~| msgid_plural"     { return OBSOLETE_PREVIOUS_MSGID_PLURAL; }
"#~ msgstr"            { return OBSOLETE_MSGSTR; }
"#~ "\"(\\.|[^\\"])*\"   {
	polval.str_val = g_strndup (yytext + 4, yyleng - 5);
	return OBSOLETE_STRING;
}
"#:".*"\n"          {
	polval.str_val = g_strndup (yytext + 2, yyleng - 3);
	return COMMENT_POS;
}
"#,".*"\n"          {
	polval.str_val = g_strndup (yytext + 2, yyleng - 3);
	return COMMENT_SPECIAL;
}
"# ".*"\n"          {
	polval.str_val = g_strndup (yytext + 1, yyleng - 2);
	return COMMENT_STD;
}
"#\n"               {
	polval.str_val = g_strdup ("");
	return COMMENT_STD;
}
"#"[^|~\n].*"\n"       {
	polval.str_val = g_strndup (yytext + 1, yyleng - 2);
	return COMMENT_RESERVED;
}

[ \t\v\f\n]         { ; }
.                   { return INVALID; }

%%

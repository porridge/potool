%{
/*
 * potool is a program aiding editing of po files
 * Copyright (C) 1999-2002 Zbigniew Chyla
 *
 * see LICENSE for licensing info
 */
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <glib.h>
#include "po-gram.h"
#include "common.h"
#include "i18n.h"

int polineno;
int polex (void);
void poerror (char *s);

static GSList *entries = NULL, *obsolete_entries = NULL;
static char *concat_strings (GSList *slist);

%}

%union {
	int int_val;
	char *str_val;
	GSList *gslist_val;
	PoEntry *entry_val;
	PoObsoleteEntry *obsolete_entry_val;
	PoComments comments_val;
	MsgStrX *msgstrx_val;
}

%token MSGCTXT OBSOLETE_MSGCTXT MSGID MSGID_PLURAL MSGSTR OBSOLETE_MSGID OBSOLETE_MSGID_PLURAL OBSOLETE_MSGSTR INVALID
%token <str_val> MSGSTR_X
%token <str_val> STRING
%token <str_val> OBSOLETE_STRING
%token <str_val> COMMENT_STD
%token <str_val> COMMENT_POS
%token <str_val> COMMENT_SPECIAL
%token <str_val> COMMENT_RESERVED

%type <str_val> msgctx
%type <str_val> obsolete_msgctx
%type <gslist_val> string_list
%type <gslist_val> obsolete_string_list
%type <gslist_val> really_obsolete_string_list
%type <gslist_val> msg_list
%type <gslist_val> obsolete_msg_list
%type <gslist_val> msgstr_x_list
%type <gslist_val> obsolete_msgstr_x_list
%type <msgstrx_val> msgstr_x
%type <msgstrx_val> obsolete_msgstr_x
%type <comments_val> comments
%type <entry_val> msg
%type <obsolete_entry_val> obsolete_msg

%start translation_unit
%%

translation_unit
	: msg_list
	{
		entries = g_slist_reverse ($1);
		obsolete_entries = NULL;
	}
	| msg_list obsolete_msg_list
	{
		entries = g_slist_reverse ($1);
		obsolete_entries = g_slist_reverse ($2);
	}
	;

msg_list
	: msg
	{
		$$ = g_slist_append (NULL, $1);
	}
	| msg_list msg
	{
		$$ = g_slist_prepend ($1, $2);
	}
	;

obsolete_msg_list
	: obsolete_msg
	{
		$$ = g_slist_append (NULL, $1);
	}
	| obsolete_msg_list obsolete_msg
	{
		$$ = g_slist_prepend ($1, $2);
	}
	;

comments
	: /* empty */
	{
		$$.std = NULL;
		$$.pos = NULL;
		$$.spec = NULL;
		$$.res = NULL;
	}
	| comments COMMENT_STD
	{
		$$ = $1;
		$$.std =  g_slist_append ($$.std, $2);
	}
	| comments COMMENT_POS
	{
		$$ = $1;
		$$.pos =  g_slist_append ($$.pos, $2);
	}
	| comments COMMENT_SPECIAL
	{
		$$ = $1;
		$$.spec =  g_slist_append ($$.spec, $2);
	}
	| comments COMMENT_RESERVED
	{
		$$ = $1;
		$$.res =  g_slist_append ($$.res, $2);
	}
	;

msgstr_x
	: MSGSTR MSGSTR_X string_list
	{
		$$ = g_new(MsgStrX, 1);
		$$->n = atoi($2);
		$$->str = concat_strings ($3);
		g_free ($2);
		g_slist_free_custom ($3, g_free);
	}
	;

obsolete_msgstr_x
	: OBSOLETE_MSGSTR MSGSTR_X obsolete_string_list
	{
		$$ = g_new(MsgStrX, 1);
		$$->n = atoi($2);
		$$->str = concat_strings ($3);
		g_free ($2);
		g_slist_free_custom ($3, g_free);
	}
	;

msgstr_x_list
	: msgstr_x
	{
		$$ = g_slist_append (NULL, $1);
	}
	| msgstr_x_list msgstr_x
	{
		$$ = g_slist_append ($1, $2);
	}
	;

obsolete_msgstr_x_list
	: obsolete_msgstr_x
	{
		$$ = g_slist_append (NULL, $1);
	}
	| obsolete_msgstr_x_list obsolete_msgstr_x
	{
		$$ = g_slist_append ($1, $2);
	}
	;

msgctx
	: /* empty */
	{
		$$ = NULL;
	}
	| MSGCTXT string_list
	{
		$$ = concat_strings ($2);
		g_slist_free_custom ($2, g_free);
	}
	;

obsolete_msgctx
	: /* empty */
	{
		$$ = NULL;
	}
	| OBSOLETE_MSGCTXT obsolete_string_list
	{
		$$ = concat_strings ($2);
		g_slist_free_custom ($2, g_free);
	}
	;

msg
	: comments msgctx MSGID string_list MSGSTR string_list
	{
		GSList *l;

		$$ = g_new (PoEntry, 1);
		$$->ctx = $2;
		$$->id = concat_strings ($4);
		$$->id_plural = NULL;
		$$->str = concat_strings ($6);
		$$->msgstrxs = NULL;
		$$->comments = $1;
		$$->is_fuzzy = $$->is_c_format = 0;
		for (l = $$->comments.spec; l != NULL; l = l->next) {
			char *s = l->data;

			if (strstr (s, " fuzzy") != NULL) {
				$$->is_fuzzy = 1;
			}
			if (strstr (s, " c-format") != NULL) {
				$$->is_c_format = 1;
			}
		}
		g_slist_free_custom ($4, g_free);
		g_slist_free_custom ($6, g_free);
	}
	| comments msgctx MSGID string_list MSGID_PLURAL string_list msgstr_x_list
	{
		GSList *l;

		$$ = g_new (PoEntry, 1);
		$$->ctx = $2;
		$$->id = concat_strings ($4);
		$$->id_plural = concat_strings ($6);
		$$->str = NULL;
		$$->msgstrxs = $7;
		$$->comments = $1;
		$$->is_fuzzy = $$->is_c_format = 0;
		for (l = $$->comments.spec; l != NULL; l = l->next) {
			char *s = l->data;

			if (strstr (s, " fuzzy") != NULL) {
				$$->is_fuzzy = 1;
			}
			if (strstr (s, " c-format") != NULL) {
				$$->is_c_format = 1;
			}
		}
		g_slist_free_custom ($4, g_free);
		g_slist_free_custom ($6, g_free);
	}
	;

obsolete_msg
	: comments obsolete_msgctx OBSOLETE_MSGID obsolete_string_list OBSOLETE_MSGSTR obsolete_string_list
	{
		GSList *l;

		$$ = g_new (PoObsoleteEntry, 1);
		$$->ctx = $2;
		$$->id = concat_strings ($4);
		$$->id_plural = NULL;
		$$->str = concat_strings ($6);
		$$->msgstrxs = NULL;
		$$->comments = $1;
		$$->is_fuzzy = $$->is_c_format = 0;
		for (l = $$->comments.spec; l != NULL; l = l->next) {
			char *s = l->data;

			if (strstr (s, " fuzzy") != NULL) {
				$$->is_fuzzy = 1;
			}
			if (strstr (s, " c-format") != NULL) {
				$$->is_c_format = 1;
			}
		}
		g_slist_free_custom ($4, g_free);
		g_slist_free_custom ($6, g_free);
	}
	| comments obsolete_msgctx OBSOLETE_MSGID obsolete_string_list OBSOLETE_MSGID_PLURAL obsolete_string_list obsolete_msgstr_x_list
	{
		GSList *l;

		$$ = g_new (PoObsoleteEntry, 1);
		$$->ctx = $2;
		$$->id = concat_strings ($4);
		$$->id_plural = concat_strings ($6);
		$$->str = NULL;
		$$->msgstrxs = $7;
		$$->comments = $1;
		$$->is_fuzzy = $$->is_c_format = 0;
		for (l = $$->comments.spec; l != NULL; l = l->next) {
			char *s = l->data;

			if (strstr (s, " fuzzy") != NULL) {
				$$->is_fuzzy = 1;
			}
			if (strstr (s, " c-format") != NULL) {
				$$->is_c_format = 1;
			}
		}
		g_slist_free_custom ($4, g_free);
		g_slist_free_custom ($6, g_free);
	}
	;

string_list
	: STRING
	{
		$$ = g_slist_append (NULL, $1);
	}
	| string_list STRING
	{
		$$ = g_slist_append ($1, $2);
	}
	;

obsolete_string_list
	: STRING
	{
		$$ = g_slist_append (NULL, $1);
	}
	| STRING really_obsolete_string_list
	{
		$$ = g_slist_prepend ($2, $1);
	}
	;

really_obsolete_string_list
	: OBSOLETE_STRING
	{
		$$ = g_slist_append (NULL, $1);
	}
	| really_obsolete_string_list OBSOLETE_STRING
	{
		$$ = g_slist_append ($1, $2);
	}
	;

/* ---------- ---------- */

%%
#include <stdio.h>

extern char potext[];
extern int column;

void po_init_parser (void)
{
}

static char *
concat_strings (GSList *slist)
{
	GSList *l;
	int total_len;
	char *str, *p;

	total_len = 0;
	for (l = slist; l != NULL; l = l->next) {
		total_len += strlen (l->data);
	}
	str = g_malloc (total_len + 1);
	p = str;
	for (l = slist; l != NULL; l = l->next) {
		char *s = l->data;
		int len;

		len = strlen (s);
		if (len > 0) {
			g_memmove (p, s, len);
			p += len;
		}
	}
	str[total_len] = '\0';
	return str;
}

void
poerror (char *s)
{
	fflush (stdout);
	g_error (_("Parse error at line %d\n"), polineno);
}

PoFile *
po_read (char *fn)
{
	PoFile *pof;

	po_scan_open_file (fn);
	po_init_parser ();
	poparse ();
	po_scan_close_file ();

	pof = g_new (PoFile, 1);
	pof->entries = entries;
	pof->obsolete_entries = obsolete_entries;

	return pof;
}

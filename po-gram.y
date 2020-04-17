%{
/*
 * potool is a program aiding editing of po files
 * Copyright (C) 1999-2002 Zbigniew Chyla
 * Copyright (C) 2000-2019 Marcin Owsiany <porridge@debian.org>
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

extern int polineno;
int polex (void);
void poerror (const char *s);

static GSList *entries = NULL, *obsolete_entries = NULL;
static StringBlock *concat_strings (GSList *slist);

%}

%define parse.error verbose

%union {
	int int_val;
	char *str_val;
	StringBlock *stringblock_val;
	GSList *gslist_val;
	PoEntry *entry_val;
	PoComments comments_val;
	PoPrevious previous_val;
	MsgStrX *msgstrx_val;
}

%token MSGCTXT PREVIOUS_MSGCTXT OBSOLETE_MSGCTXT OBSOLETE_PREVIOUS_MSGCTXT
%token MSGID MSGID_PLURAL PREVIOUS_MSGID PREVIOUS_MSGID_PLURAL
%token OBSOLETE_MSGID OBSOLETE_MSGID_PLURAL OBSOLETE_PREVIOUS_MSGID OBSOLETE_PREVIOUS_MSGID_PLURAL
%token MSGSTR OBSOLETE_MSGSTR INVALID
%token <str_val> MSGSTR_X
%token <str_val> STRING
%token <str_val> OBSOLETE_STRING
%token <str_val> COMMENT_STD
%token <str_val> COMMENT_POS
%token <str_val> COMMENT_SPECIAL
%token <str_val> COMMENT_RESERVED

%type <stringblock_val> msgctx
%type <stringblock_val> obsolete_msgctx
%type <stringblock_val> previous_ctx
%type <stringblock_val> obsolete_previous_ctx
%type <stringblock_val> previous_id
%type <stringblock_val> obsolete_previous_id
%type <stringblock_val> previous_id_plural
%type <stringblock_val> obsolete_previous_id_plural
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
%type <previous_val> previous
%type <previous_val> obsolete_previous
%type <entry_val> msg
%type <entry_val> obsolete_msg

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

previous_ctx
	: /* empty */
	{
		$$ = NULL;
	}
	| PREVIOUS_MSGCTXT string_list
	{
		$$ = concat_strings($2);
		g_slist_free_custom ($2, g_free);
	}
	;

previous_id
	: /* empty */
	{
		$$ = NULL;
	}
	| PREVIOUS_MSGID string_list
	{
		$$ = concat_strings($2);
		g_slist_free_custom ($2, g_free);
	}
	;

previous_id_plural
	: /* empty */
	{
		$$ = NULL;
	}
	| PREVIOUS_MSGID_PLURAL string_list
	{
		$$ = concat_strings($2);
		g_slist_free_custom ($2, g_free);
	}
	;

previous
	: previous_ctx previous_id previous_id_plural
	{
		$$.ctx = $1;
		$$.id = $2;
		$$.id_plural = $3;
	}
	;

obsolete_previous_ctx
	: /* empty */
	{
		$$ = NULL;
	}
	| OBSOLETE_PREVIOUS_MSGCTXT string_list
	{
		$$ = concat_strings($2);
		g_slist_free_custom ($2, g_free);
	}
	;

obsolete_previous_id
	: /* empty */
	{
		$$ = NULL;
	}
	| OBSOLETE_PREVIOUS_MSGID string_list
	{
		$$ = concat_strings($2);
		g_slist_free_custom ($2, g_free);
	}
	;

obsolete_previous_id_plural
	: /* empty */
	{
		$$ = NULL;
	}
	| OBSOLETE_PREVIOUS_MSGID_PLURAL string_list
	{
		$$ = concat_strings($2);
		g_slist_free_custom ($2, g_free);
	}
	;

obsolete_previous
	: obsolete_previous_ctx obsolete_previous_id obsolete_previous_id_plural
	{
		$$.ctx = $1;
		$$.id = $2;
		$$.id_plural = $3;
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
	: comments previous msgctx MSGID string_list MSGSTR string_list
	{
		GSList *l;

		$$ = g_new (PoEntry, 1);
		$$->ctx = $3;
		$$->id = concat_strings ($5);
		$$->id_plural = NULL;
		$$->str = concat_strings ($7);
		$$->msgstrxs = NULL;
		$$->comments = $1;
		$$->previous = $2;
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
		g_slist_free_custom ($5, g_free);
		g_slist_free_custom ($7, g_free);
	}
	| comments previous msgctx MSGID string_list MSGID_PLURAL string_list msgstr_x_list
	{
		GSList *l;

		$$ = g_new (PoEntry, 1);
		$$->ctx = $3;
		$$->id = concat_strings ($5);
		$$->id_plural = concat_strings ($7);
		$$->str = NULL;
		$$->msgstrxs = $8;
		$$->comments = $1;
		$$->previous = $2;
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
		g_slist_free_custom ($5, g_free);
		g_slist_free_custom ($7, g_free);
	}
	;

obsolete_msg
	: comments obsolete_previous obsolete_msgctx OBSOLETE_MSGID obsolete_string_list OBSOLETE_MSGSTR obsolete_string_list
	{
		GSList *l;

		$$ = g_new (PoEntry, 1);
		$$->ctx = $3;
		$$->id = concat_strings ($5);
		$$->id_plural = NULL;
		$$->str = concat_strings ($7);
		$$->msgstrxs = NULL;
		$$->comments = $1;
		$$->previous = $2;
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
		g_slist_free_custom ($5, g_free);
		g_slist_free_custom ($7, g_free);
	}
	| comments obsolete_previous obsolete_msgctx OBSOLETE_MSGID obsolete_string_list OBSOLETE_MSGID_PLURAL obsolete_string_list obsolete_msgstr_x_list
	{
		GSList *l;

		$$ = g_new (PoEntry, 1);
		$$->ctx = $3;
		$$->id = concat_strings ($5);
		$$->id_plural = concat_strings ($7);
		$$->str = NULL;
		$$->msgstrxs = $8;
		$$->comments = $1;
		$$->previous = $2;
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
		g_slist_free_custom ($5, g_free);
		g_slist_free_custom ($7, g_free);
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

static StringBlock*
concat_strings (GSList *slist)
{
	GSList *l;
	int total_len = 0, i = 0;
	char *p;
	StringBlock *ret = g_new(StringBlock, 1);
	ret->num_lines = 0;

	for (l = slist; l != NULL; l = l->next) {
		total_len += strlen (l->data);
		ret->num_lines++;
	}
	ret->str = g_malloc (total_len + 1);
	ret->line_lengths = g_malloc (sizeof(int) * ret->num_lines);
	p = ret->str;
	for (l = slist; l != NULL; l = l->next) {
		char *s = l->data;
		int len = strlen (s);
		if (len > 0) {
			memmove (p, s, len);
			p += len;
		}
		ret->line_lengths[i++] = len;
	}
	ret->str[total_len] = '\0';
	return ret;
}

void
poerror (const char *s)
{
	fflush (stdout);
	po_error (_("Parse error at line %d: %s\n"), polineno, s);
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

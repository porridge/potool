/*
 * potool is a program aiding editing of po files
 * Copyright (C) 1999-2002 Zbigniew Chyla
 * Copyright (C) 2000-2012 Marcin Owsiany <porridge@debian.org>
 *
 * see LICENSE for licensing info
 */
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <glib.h>
#include <getopt.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include "i18n.h"
#include "common.h"
#include "po-gram.h"

#define RMARGIN 80


typedef gboolean po_filter_func (PoEntry *);

void
po_error(const gchar *format, ...)
{
	va_list ap;
	va_start(ap, format);
	g_logv(G_LOG_DOMAIN, G_LOG_LEVEL_CRITICAL, format, ap);
	va_end(ap);
	exit(1);
}

void
msgstrx_free(MsgStrX *msgstrx)
{
	g_free (msgstrx->str);
	g_free (msgstrx);
}

void
po_list_str_dup(GSList *list)
{
	GSList *l;
	for (l = list; l != NULL; l = l->next) {
		char *s = l->data;
		l->data = g_strdup (s);
	}
}

void
po_list_msgstrx_dup(GSList *list)
{
	GSList *l;
	for (l = list; l != NULL; l = l->next) {
		MsgStrX *s = l->data;
		MsgStrX *n = g_new (MsgStrX, 1);
		n->n = s->n;
		n->str = g_strdup (s->str);
		l->data = n;
	}
}

PoEntry *
po_entry_copy (PoEntry *ret, PoEntry *po)
{
	if (ret == NULL)
		ret = g_new (PoEntry, 1);

	ret->comments.std = g_slist_copy (po->comments.std);
	po_list_str_dup(ret->comments.std);
	ret->comments.pos = g_slist_copy (po->comments.pos);
	po_list_str_dup(ret->comments.pos);
	ret->comments.res = g_slist_copy (po->comments.res);
	po_list_str_dup(ret->comments.res);
	ret->comments.spec = g_slist_copy (po->comments.spec);
	po_list_str_dup(ret->comments.spec);

	ret->previous.ctx = g_strdup (po->previous.ctx);
	ret->previous.id = g_strdup (po->previous.id);
	ret->previous.id_plural = g_strdup (po->previous.id_plural);

	ret->is_fuzzy = po->is_fuzzy;
	ret->is_c_format = po->is_c_format;

	ret->ctx = g_strdup (po->ctx);
	ret->id = g_strdup (po->id);
	ret->id_plural = g_strdup (po->id_plural);
	ret->str = g_strdup (po->str);

	ret->msgstrxs = g_slist_copy (po->msgstrxs);
	po_list_msgstrx_dup(ret->msgstrxs);

	return ret;
}

void
po_entry_free (PoEntry *po)
{
	g_slist_free_custom (po->comments.std, g_free);
	g_slist_free_custom (po->comments.pos, g_free);
	g_slist_free_custom (po->comments.res, g_free);
	g_slist_free_custom (po->comments.spec, g_free);
	g_slist_free_custom (po->msgstrxs, msgstrx_free);
	g_free (po->previous.id);
	g_free (po->previous.id_plural);
	g_free (po->previous.ctx);

	g_free (po->id);
	g_free (po->id_plural);
	g_free (po->ctx);
	g_free (po->str);
	g_free (po);
}

void
po_free (PoFile *pof)
{
	g_slist_free_custom (pof->entries, po_entry_free);
	g_slist_free_custom (pof->obsolete_entries, po_entry_free);
	g_free (pof);
}

/* --- PoEntry filters --- */

gint
msgstrx_is_same_firstchar (gconstpointer a, gconstpointer b)
{
	const MsgStrX *as = a, *bs = b;
	return ! (as == bs || (as && bs && ((as->str == bs->str) || (as->str && bs->str && as->str[0] == bs->str[0]))));
}

static gboolean
po_filter_translated (PoEntry *po)
{
	if (po->str)
		return po->str[0] != '\0';
	
	/* With plural forms, only return true if ALL forms are translated. The
	 * list is guaranteed to be non-empty by the grammar */
	else {
		MsgStrX empty = { "", 0 };
		return NULL == g_slist_find_custom (po->msgstrxs, &empty, msgstrx_is_same_firstchar);
	}
}

static gboolean
po_filter_not_translated (PoEntry *po)
{
	if (po->str)
		return po->str[0] == '\0';

	/* With plural forms, only return true if ANY forms are not translated.
	 * The list is guaranteed to be non-empty by the grammar */
	else {
		MsgStrX empty = { "", 0 };
		return NULL != g_slist_find_custom (po->msgstrxs, &empty, msgstrx_is_same_firstchar);
	}
}

static gboolean
po_filter_not_translated_and_header (PoEntry *po)
{
	if (po->id[0] == '\0')
		return 1;
	else
		return po_filter_not_translated (po);
}

static gboolean
po_filter_fuzzy (PoEntry *po)
{
	return po->is_fuzzy;
}

static gboolean
po_filter_not_fuzzy (PoEntry *po)
{
	return !po->is_fuzzy;
}

/* -- */

static void
po_apply_filter (PoFile *pof, po_filter_func *filter)
{
	GSList *npo_list, *l;

	for (npo_list = NULL, l = pof->entries; l != NULL; l = l->next) {
		if (filter ((PoEntry *) l->data)) {
			npo_list = g_slist_prepend (npo_list, l->data);
		} else {
			po_entry_free (l->data);
		}
	}
	g_slist_free (pof->entries);
	pof->entries = g_slist_reverse (npo_list);

	for (npo_list = NULL, l = pof->obsolete_entries; l != NULL; l = l->next) {
		if (filter ((PoEntry *) l->data)) {
			npo_list = g_slist_prepend (npo_list, l->data);
		} else {
			po_entry_free (l->data);
		}
	}
	g_slist_free (pof->obsolete_entries);
	pof->obsolete_entries = g_slist_reverse (npo_list);

}

typedef enum {
	FUZZY_FILTER            = 1 << 0,
	NOT_FUZZY_FILTER        = 1 << 1,
	TRANSLATED_FILTER       = 1 << 2,
	NOT_TRANSLATED_FILTER   = 1 << 3,
	NOT_TRANSLATED_H_FILTER	= 1 << 4, // same as NOT_TRANSLATED_FILTER but includes msgid "" header
	OBSOLETE_FILTER         = 1 << 5,
	NOT_OBSOLETE_FILTER     = 1 << 6,
} PoFilters;


static void
po_apply_filters (PoFile *pof, PoFilters filters)
{
	if ((filters & FUZZY_FILTER) != 0) {
		po_apply_filter (pof, po_filter_fuzzy);
	}
	if ((filters & NOT_FUZZY_FILTER) != 0) {
		po_apply_filter (pof, po_filter_not_fuzzy);
	}
	if ((filters & TRANSLATED_FILTER) != 0) {
		po_apply_filter (pof, po_filter_translated);
	}
	if ((filters & NOT_TRANSLATED_FILTER) != 0) {
		po_apply_filter (pof, po_filter_not_translated);
	}
	if ((filters & NOT_TRANSLATED_H_FILTER) != 0) {
		po_apply_filter (pof, po_filter_not_translated_and_header);
	}
	if ((filters & OBSOLETE_FILTER) != 0) {
		g_slist_free_custom (pof->entries, po_entry_free);
		pof->entries = NULL;
	}
	if ((filters & NOT_OBSOLETE_FILTER) != 0) {
		g_slist_free_custom (pof->obsolete_entries, po_entry_free);
		pof->obsolete_entries = NULL;
	}
}

static void
po_copy_msgid (PoFile *pof)
{
	GSList *l;

	for (l = pof->entries; l != NULL; l = l->next) {
		PoEntry *po = l->data;

		if (po->str) {
			g_free (po->str);
			po->str = g_strdup (po->id);
		} else {
			MsgStrX *m = g_new (MsgStrX, 1);
			m->n = 0;
			m->str = g_strdup (po->id);
			g_slist_free_custom (po->msgstrxs, msgstrx_free);
			po->msgstrxs = g_slist_append(NULL, m);
		}
	}

}

/* --- */

typedef enum {
	NO_CTX		= 1 << 0,
	NO_ID           = 1 << 1,
	NO_STR          = 1 << 2,
	NO_STD_COMMENT  = 1 << 3,
	NO_POS_COMMENT  = 1 << 4,
	NO_SPEC_COMMENT = 1 << 5,
	NO_RES_COMMENT  = 1 << 6,
	NO_PREVIOUS     = 1 << 7,
	NO_TRANSLATION  = 1 << 8,
	NO_LINF         = 1 << 9
} po_write_modes;

enum {
	SEP1 = ' ',
	SEP2 = '\t'
};

int potool_printf(char *format, ...)
{
	va_list ap;
	int ret;
	va_start(ap, format);
	ret = vprintf(format, ap);
	if (ret < 0)
		po_error(_("printf() failed with code %d: %s"), ret, strerror(errno));
	va_end(ap);
	return ret;
}

static void
print_multi_line (const char *s, int start_offset, const char *prefix)
{
	int slen, prefix_len;
	char *eol_ptr;
	gboolean has_final_eol;
	char **lines, **ln;
	enum { max_len = 77 };

	slen = strlen (s);	
	eol_ptr = strstr (s, "\\n");
	if ((eol_ptr == NULL || (eol_ptr - s + 2 == slen))
	    && slen < (RMARGIN - 2 - start_offset)) {
		potool_printf ("\"%s\"\n", s);
		return;
	}

	potool_printf ("\"\"\n");
	prefix_len = strlen (prefix);
	has_final_eol = strcmp (s + slen - 2, "\\n") == 0;
	lines = g_strsplit (s, "\\n", 0);
	for (ln = lines; *ln != NULL; ln++) {
		char *cur;
		int offset;
		gboolean line_has_eol;

#if GLIB_MAJOR_VERSION == 2
		if (*ln[0] == '\0' && *(ln + 1) == NULL)
			continue;
#endif
		potool_printf ("%s\"", prefix);
		line_has_eol = has_final_eol || *(ln + 1) != NULL;
		offset = prefix_len;
		cur = *ln;
		do {
			int word_len = 0;
			int eol_len;
			int ret;

			while (cur[word_len] != SEP1 && cur[word_len] != SEP2 &&
			       cur[word_len] != '\0')
				word_len++;
			while (cur[word_len] == SEP1 || cur[word_len] == SEP2)
				word_len++;

			if (line_has_eol && cur[word_len] == '\0' &&
			    (word_len == 0 || (cur[word_len - 1] != SEP1 && cur[word_len - 1] != SEP2))) {
				eol_len = 2;
			} else {
				eol_len = 0;
			}
			if (offset + word_len + eol_len > max_len) {
				potool_printf ("\"\n%s\"", prefix);
				offset = prefix_len;
			}
			if ((ret = fwrite(cur, 1, word_len, stdout)) != word_len)
				po_error(_("fwrite() failed, returned %d instead of %d: %s"), ret, word_len, strerror(errno));
			offset += word_len;
			cur += word_len;
		} while (*cur != '\0');

		if (line_has_eol) {
			if (offset + 2 > max_len) {
				potool_printf ("\"\n%s\"\\n", prefix);
			} else {
				potool_printf ("\\n");
			}
		}
		potool_printf ("\"\n");
	}
	g_strfreev (lines);
}

static void
write_msgstr (char *prefix, char *str, GSList *strn, po_write_modes mode)
{
	int prefix_len = strlen(prefix);

	if (!(mode & NO_TRANSLATION)) {
		if (str) {
			potool_printf ("%smsgstr ", prefix);
			print_multi_line (str, 7 + prefix_len, prefix);
		} else {
			GSList *x;
			for (x = strn; x != NULL; x = x->next) {
				MsgStrX *m = x->data;
				potool_printf ("%smsgstr[%d] ", prefix, m->n);
				print_multi_line (m->str, 10 + prefix_len, prefix);
			}
		}
	} else {
		potool_printf ("%smsgstr \"\"\n", prefix);
	}
}

static void
po_write (PoFile *pof, po_write_modes mode)
{
	GSList *l;

	for (l = pof->entries; l != NULL; l = l->next) {
		PoEntry *po = l->data;
		GSList *ll;

		if (!(mode & NO_STD_COMMENT)) {
			for (ll = po->comments.std; ll != NULL; ll = ll->next) {
				potool_printf ("#%s\n", (char *) ll->data);
			}
		}
		if (!(mode & NO_RES_COMMENT)) {
			for (ll = po->comments.res; ll != NULL; ll = ll->next) {
				potool_printf ("#%s\n", (char *) ll->data);
			}
		}
		if (!(mode & NO_POS_COMMENT)) {
			if (!(mode & NO_LINF)) {
				for (ll = po->comments.pos; ll != NULL; ll = ll->next) {
					potool_printf ("#:%s\n", (char *) ll->data);
				}
			} else {
				for (ll = po->comments.pos; ll != NULL; ll = ll->next) {
					char *s = g_strdup ((char *) ll->data);
					char *l, *r;

					l = r = s;
					while (*r != '\0') {
						if (*r == ':') {
							*l++ = ':';
							*l++ = '1';
							while (isdigit (*++r))
								;
						} else {
							*l++ = *r++;
						}
					}
					*l = '\0';
					potool_printf ("#:%s\n", s);
					g_free (s);
				}
			}
		}
		if (!(mode & NO_SPEC_COMMENT)) {
			for (ll = po->comments.spec; ll != NULL; ll = ll->next) {
				potool_printf ("#,%s\n", (char *) ll->data);
			}
		}
		if (!(mode & NO_PREVIOUS)) {
			if (po->previous.ctx) {
				potool_printf ("#| msgctxt ");
				print_multi_line (po->previous.ctx, 11, "");
			}
			if (po->previous.id) {
				potool_printf ("#| msgid ");
				print_multi_line (po->previous.id, 9, "");
			}
			if (po->previous.id_plural) {
				potool_printf ("#| msgid_plural ");
				print_multi_line (po->previous.id, 16, "");
			}
		}
		if ((!(mode & NO_CTX)) && po->ctx) {
			potool_printf ("msgctxt ");
			print_multi_line (po->ctx, 8, "");
		}
		if (!(mode & NO_ID)) {
			potool_printf ("msgid ");
			print_multi_line (po->id, 6, "");
			if (po->id_plural) {
				potool_printf ("msgid_plural ");
				print_multi_line (po->id_plural, 13, "");
			}
		}
		if (!(mode & NO_STR)) {
			write_msgstr ("", po->str, po->msgstrxs, mode);
		}

		if (l->next != NULL) {
			potool_printf ("\n");
		}
	}

	if (pof->obsolete_entries != NULL) {
		potool_printf ("\n");
	}

	for (l = pof->obsolete_entries; l != NULL; l = l->next) {
		PoEntry *po = l->data;
		GSList *ll;

		if (!(mode & NO_STD_COMMENT)) {
			for (ll = po->comments.std; ll != NULL; ll = ll->next) {
				potool_printf ("#%s\n", (char *) ll->data);
			}
		}
		if (!(mode & NO_SPEC_COMMENT)) {
			for (ll = po->comments.spec; ll != NULL; ll = ll->next) {
				potool_printf ("#,%s\n", (char *) ll->data);
			}
		}
		if (!(mode & NO_PREVIOUS)) {
			if (po->previous.ctx) {
				potool_printf ("#~| msgctxt ");
				print_multi_line (po->previous.ctx, 12, "");
			}
			if (po->previous.id) {
				potool_printf ("#~| msgid ");
				print_multi_line (po->previous.id, 10, "");
			}
			if (po->previous.id_plural) {
				potool_printf ("#~| msgid_plural ");
				print_multi_line (po->previous.id, 17, "");
			}
		}

		if ((!(mode & NO_CTX)) && po->ctx) {
			potool_printf ("#~ msgctxt ");
			print_multi_line (po->ctx, 11, "#~ ");
		}

		if (!(mode & NO_ID)) {
			potool_printf ("#~ msgid ");
			print_multi_line (po->id, 9, "#~ ");
			if (po->id_plural) {
				potool_printf ("#~ msgid_plural ");
				print_multi_line (po->id_plural, 16, "#~ ");
			}
		}
		if (!(mode & NO_STR)) {
			write_msgstr ("#~ ", po->str, po->msgstrxs, mode);
		}

		if (l->next != NULL) {
			potool_printf ("\n");
		}
	}
}

/* - */

typedef GHashTable PoEntry_set;

static PoEntry_set *
po_set_create (GSList *po_list)
{
	GSList *l;
	GHashTable *hash = g_hash_table_new (g_str_hash, g_str_equal);
	for (l = po_list; l != NULL; l = l->next) {
		PoEntry *po = l->data;

		g_hash_table_insert (hash, po->id, po);
	}
	return hash;
}

static PoEntry_set *
po_set_update (PoEntry_set *po_set, GSList *po_list)
{
	GSList *l;

	for (l = po_list; l != NULL; l = l->next) {
		PoEntry *po = (PoEntry *) l->data, *hpo;

		if ((hpo = g_hash_table_lookup (po_set, po->id)) != NULL) {
			/* making a deep copy, since we are about to free po_list */
			po_entry_copy (hpo, po);
		} else {
			g_warning (_("Unknown msgid: %s"), po->id);
		}
	}
	return po_set;
}

int
main (int argc, char **argv)
{
	int c;
	/* -- */
	gboolean istats = FALSE;
	gboolean copy_msgid = FALSE;
	PoFilters ifilters = 0;
	po_write_modes write_mode = 0;

	/*
		FILENAME1 [FILENAME2]
		[-f f|nf|t|nt|nth|o|no]
		[-s] [-c]
		[-n ctxt|id|str|cmt|ucmt|pcmt|scmt|dcmt|tr|linf]...
		[-h]
	 */
	while ((c = getopt (argc, argv, "f:n:sch")) != EOF) {
		switch (c) {
			case 'h' :
				fprintf (stderr, _(
				"Usage: %s -i FILENAME1 [FILENAME2] [FITERS] [-s] [OUTPUT_OPTIONS] [-h]\n"
				"\n"
				), argv[0]);
				exit (EXIT_SUCCESS);
				break;
			case 'n' :
				if (strcmp (optarg, "ctxt") == 0) {
					write_mode |= NO_CTX;
				} else if (strcmp (optarg, "id") == 0) {
					write_mode |= NO_ID;
				} else if (strcmp (optarg, "str") == 0) {
					write_mode |= NO_STR;
				} else if (strcmp (optarg, "cmt") == 0) {
					write_mode |= NO_STD_COMMENT | NO_POS_COMMENT |
					              NO_SPEC_COMMENT | NO_RES_COMMENT;
				} else if (strcmp (optarg, "ucmt") == 0) {
					write_mode |= NO_STD_COMMENT;
				} else if (strcmp (optarg, "pcmt") == 0) {
					write_mode |= NO_POS_COMMENT;
				} else if (strcmp (optarg, "scmt") == 0) {
					write_mode |= NO_SPEC_COMMENT;
				} else if (strcmp (optarg, "dcmt") == 0) {
					write_mode |= NO_RES_COMMENT;
				} else if (strcmp (optarg, "tr") == 0) {
					write_mode |= NO_TRANSLATION;
				} else if (strcmp (optarg, "linf") == 0) {
					write_mode |= NO_LINF;
				} else {
					po_error (_("Unknown parameter for -n option!"));
				}
				break;
			case 's' :
				istats = TRUE;
				break;
			case 'c':
				copy_msgid = TRUE;
				break;
			case 'f' :
				if (strcmp (optarg, "f") == 0) {
					ifilters |= FUZZY_FILTER;
				} else if (strcmp (optarg, "nf") == 0) {
					ifilters |= NOT_FUZZY_FILTER;
				} else if (strcmp (optarg, "t") == 0) {
					ifilters |= TRANSLATED_FILTER;
				} else if (strcmp (optarg, "nt") == 0) {
					ifilters |= NOT_TRANSLATED_FILTER;
				} else if (strcmp (optarg, "nth") == 0) {
					ifilters |= NOT_TRANSLATED_H_FILTER;
				} else if (strcmp (optarg, "o") == 0) {
					ifilters |= OBSOLETE_FILTER;
				} else if (strcmp (optarg, "no") == 0) {
					ifilters |= NOT_OBSOLETE_FILTER;
				} else {
					po_error (_("Unknown filter \"%s\"!"), optarg);
				}
				break;
			case ':' :
				po_error (_("Invalid parameter!"));
				break;
			case '?' :
				po_error (_("Invalid option!"));
				break;
			default :
				g_assert_not_reached ();
		}
	}

	if (optind >= argc) {
		po_error (_("Input file not specified!"));
	}
	if (argc - optind == 1) {
		PoFile *pof;
		char *ifn = argv[optind];

		pof = po_read (ifn);
		po_apply_filters (pof, ifilters);

		if (istats) {
			potool_printf (_("%d\n"), g_slist_length (pof->entries));
		} else {
			if (copy_msgid) {
				po_copy_msgid (pof);
			}
			po_write (pof, write_mode);
		}
		po_free (pof);
	} else {
		PoFile *bpof, *pof;
		PoEntry_set *bpo_set;
		char *bfn = argv[optind], *fn = argv[optind + 1];

		bpof = po_read (bfn);
		bpo_set = po_set_create (bpof->entries);
		pof = po_read (fn);
		po_apply_filters (pof, ifilters);
		if (copy_msgid) {
			po_copy_msgid (pof);
		}
		bpo_set = po_set_update (bpo_set, pof->entries);
		po_write (bpof, write_mode);
		po_free (bpof);
		po_free (pof);
	}
	if (fflush(stdout) != 0)
		po_error(_("fflush(stdout) failed: %s"), strerror(errno));

	return 0;
}

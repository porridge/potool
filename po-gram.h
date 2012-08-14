/*
 * potool is a program aiding editing of po files
 * Copyright (C) 1999-2002 Zbigniew Chyla
 * Copyright (C) 2000-2012 Marcin Owsiany <porridge@debian.org>
 *
 * see LICENSE for licensing info
 */
#ifndef PO_GRAM_H
#define PO_GRAM_H

#include <glib.h>

void po_scan_open_file(char *fn);
void po_scan_close_file(void);
void po_init_parser(void);

/* ---- */

typedef struct {
	GSList *std, *pos, *res;
	GSList *spec;
} PoComments;

typedef struct {
	char *ctx, *id, *id_plural;
} PoPrevious;

typedef struct {
	char *str;
	int n;
} MsgStrX;

typedef struct {
	PoComments comments;
	PoPrevious previous;
	gboolean is_fuzzy, is_c_format;
	char *ctx, *id, *id_plural, *str;
	GSList *msgstrxs;
} PoEntry;

typedef struct {
	GSList *entries, *obsolete_entries;
} PoFile;

PoFile *po_read (char *fn);

#endif /* PO_GRAM_H */

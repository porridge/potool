/*
 * potool is a program aiding editing of po files
 * Copyright (C) 1999-2002 Zbigniew Chyla
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
	PoComments comments;
	gboolean is_fuzzy, is_c_format;
	char *id, *str;
} PoEntry;

typedef struct {
	PoComments comments;
	gboolean is_fuzzy, is_c_format;
	char *id, *str;
} PoObsoleteEntry;

typedef struct {
	GSList *entries, *obsolete_entries;
} PoFile;

PoFile *po_read (char *fn);

#endif /* PO_GRAM_H */

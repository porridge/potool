/*
 * potool is a program aiding editing of po files
 * Copyright (C) 1999-2002 Zbigniew Chyla
 *
 * see LICENSE for licensing info
 */
#ifndef COMMON_H
#define COMMON_H

#include <glib.h>

#define g_slist_free_custom(list,free_func) \
G_STMT_START { \
	GSList *potool_list = (list), *potool_l; \
	for (potool_l = potool_list; potool_l != NULL; potool_l = potool_l->next) \
		free_func (potool_l->data); \
	g_slist_free (potool_list); \
} G_STMT_END

#endif /* COMMON_H */

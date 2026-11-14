#!/bin/sed -urf
# -*- coding: UTF-8, tab-width: 2 -*-

# /^\s*(#|$)/d
s~\f~~g
s~\s+$~~

s~^([^"'\\]*)\$\{($\
  |dd_dir|$\
  |dd_proj|$\
  |dd_tpl|$\
  |dd_tpl_bn|$\
  )\}(\x22|\x27)~\1\3\f<var \2 >~

s~^($1|[ \#\-]*)\$\{($2|dd_cfg)\}($3|\x22|\x27|$\
  )($4|[A-Za-z0-9_]+)($5|=|: *)($6|[A-Za-z0-9_]*)($7|\x22|\x27|$\
  )~\1\3\4\5\f<\2 \f<fallback_id \6 \4 > >\7~
s~\$\{(dd_cfg) ([A-Za-z0-9_]+)\}(\x22|\x27)~\3\f<\1 \2 >~

s~\f<fallback_id (\S+) \S+ >~\1~g
s~\f<fallback_id  (\S+) >~\1~g

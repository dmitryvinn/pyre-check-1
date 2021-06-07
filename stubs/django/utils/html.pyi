# Copyright (c) Facebook, Inc. and its affiliates.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

# pyre-unsafe

from django.utils.safestring import SafeText

def escape(text: str) -> str: ...
def conditional_escape(text: str) -> str: ...
def format_html(format_string, *args, **kwargs) -> SafeText: ...
def format_html_join(sep, format_string, args_generator) -> SafeText: ...
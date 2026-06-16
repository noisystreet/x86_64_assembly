# Minimal makefile for Sphinx documentation
#

# You can set these variables from the command line, and also
# from the environment for the first two.
SPHINXOPTS    ?=
SPHINXBUILD   ?= python3 -m sphinx
SOURCEDIR     = source
BUILDDIR      = _build

# Put it first so that "make" without argument is like "make html".
.DEFAULT_GOAL := html

help:
	@$(SPHINXBUILD) -M help "$(SOURCEDIR)" "$(BUILDDIR)" $(SPHINXOPTS) $(O)

.PHONY: help Makefile clean precommit check serve

# Catch-all target: route all unknown targets to Sphinx using the new
# "make mode" option.
%: Makefile
	@$(SPHINXBUILD) -M $@ "$(SOURCEDIR)" "$(BUILDDIR)" $(SPHINXOPTS) $(O)

# 预提交检查：验证 RST 语法
precommit:
	@bash scripts/precommit-check.sh

# html 构建前自动运行 precommit 检查
# 显式规则覆盖 %: Makefile 泛匹配
html: Makefile precommit
	@$(SPHINXBUILD) -M html "$(SOURCEDIR)" "$(BUILDDIR)" $(SPHINXOPTS) $(O)

# 编译验证所有示例
check:
	@echo "=== 验证示例代码编译 ==="
	@mkdir -p /tmp/asm-check
	@errors=0; \
	for asm in $(SOURCEDIR)/examples/*.asm; do \
		name=$$(basename "$$asm" .asm); \
		echo -n "  [NASM] $$name... "; \
		if nasm -f elf64 "$$asm" -o "/tmp/asm-check/$$name.o" 2>/tmp/asm-check/err.txt; then \
			if ld "/tmp/asm-check/$$name.o" -o "/tmp/asm-check/$$name" 2>/tmp/asm-check/err_ld.txt; then \
				echo "✓"; \
			else \
				echo "✗ (ld failed)"; \
				cat /tmp/asm-check/err_ld.txt; \
				errors=$$((errors + 1)); \
			fi; \
		else \
			echo "✗"; \
			cat /tmp/asm-check/err.txt; \
			errors=$$((errors + 1)); \
		fi; \
	done; \
	rm -rf /tmp/asm-check; \
	if [ $$errors -eq 0 ]; then \
		echo "=== 所有示例编译通过 ==="; \
	else \
		echo "=== $$errors 个示例编译失败 ==="; \
		exit 1; \
	fi

# 本地预览服务器（默认 8000 端口）
serve: html
	@echo "Open http://localhost:8000/ in your browser"
	@cd $(BUILDDIR)/html && python3 -m http.server $(PORT)

# 增强 clean：同时清理示例编译产物
clean:
	rm -rf $(BUILDDIR)
	find $(SOURCEDIR)/examples -name '*.o' -delete
	find $(SOURCEDIR)/examples -type f ! -name '*.asm' ! -name '*.rst' -delete

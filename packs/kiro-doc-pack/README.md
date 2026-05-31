# kiro-doc-pack

> 一组与具体业务无关的 Kiro 文档协同 steering 包，可在任意仓库一键启用。

**版本：v1.0.0 | 日期：2026-05 | 状态：生效**

---

## 一、包含什么

| 文件 | 作用 |
|---|---|
| `steering/doc-coauthoring.md` | 设计文档结构、命名、版本快照、伪代码块、失效路径等约定 |
| `steering/canvas-design.md` | 流程图、状态机、ASCII 形态图、Mermaid 模板与符号语义 |
| `steering/theme-factory.md` | 标题层级、强调规则、表格、代码块、中英混排 |

> 这三个文件**互相引用**：`theme-factory` 引用 `canvas-design` 的符号语义，`doc-coauthoring` 与 `canvas-design` 在 K 线图与流程图分工上互补。建议三件套一起装。

---

## 二、安装到目标仓库

### 2.1 一键脚本（推荐）

在目标仓库根目录执行：

```bash
curl -fsSL https://raw.githubusercontent.com/jbz9/priceAction/main/packs/kiro-doc-pack/install.sh | bash
```

> 默认拉取 `main` 分支版本。要锁定某个版本，先 `export KIRO_DOC_PACK_REF=v1.0.0` 再执行（前提：该 tag 已在仓库存在）。
>
> 已存在同名文件**不会覆盖**。要强制覆盖：
>
> ```bash
> curl -fsSL https://raw.githubusercontent.com/jbz9/priceAction/main/packs/kiro-doc-pack/install.sh | bash -s -- --force
> ```

### 2.2 Git Submodule

若希望随主仓库 pin 住某个版本并能 `git pull` 升级：

```bash
git submodule add https://github.com/jbz9/priceAction.git vendor/priceAction
git submodule update --init
mkdir -p .kiro/steering
cp vendor/priceAction/packs/kiro-doc-pack/steering/*.md .kiro/steering/
```

> 缺点：拉了整个 priceAction 仓库的历史。未来若拆出独立 repo，可改为引用独立仓库。

### 2.3 手动复制

直接从本目录把 `steering/*.md` 三个文件复制到目标仓库的 `.kiro/steering/`。

---

## 三、卸载

```bash
rm .kiro/steering/{doc-coauthoring,canvas-design,theme-factory}.md
```

---

## 四、自定义

安装后这三个文件就是普通仓库内文件，可以**直接修改**作为本地变体。建议：

+ 不要删除原有章节标题（保留可被本 pack 升级脚本识别的结构）。
+ 在文件末尾追加 `## 99. 本仓库特化` 章节存放 override，便于未来合并上游更新时不冲突。

---

## 五、版本约定

+ **major（X.0.0）**：章节顺序大改、变量命名规范不兼容、强制条款删除。需要在升级时重写 override。
+ **minor（1.X.0）**：新增章节、新增可选规则、补丁式增强。一般兼容。
+ **patch（1.0.X）**：错别字、措辞优化、链接修正。完全兼容。

CHANGELOG 追加在每个 steering 文件末尾。

---

## 六、未来计划

> 等本 pack 稳定后会拆为独立仓库 `jbz9/kiro-doc-pack`，并提供：
> + GitHub Releases 上传 tar.gz / zip
> + 通过 GitHub Actions 自动给所有 tag 打包并校验 `install.sh`
> + 在 README 加 marketplace.json 形式的描述以便未来集成 Kiro skill marketplace

在那之前，本目录是单一可信来源（single source of truth）。

# MythSurvivor 代码风格

这些规则适用于后续 Godot 4.x GDScript 实现工作。

## 语言与引擎

- 玩法和 UI 代码使用 GDScript。
- 面向 Godot 4.x API。
- 在可行范围内使用类型化 GDScript。
- 每个脚本只负责一个清晰职责。

## 命名

名称应清晰、具体、可读。

```gdscript
class_name EnemyStats

@export var max_health: float = 10.0
@export var move_speed: float = 80.0

func apply_damage(amount: float) -> void:
    pass
```

### 文件与文件夹

- 文件夹：使用 `snake_case`。
- GDScript 文件：使用 `snake_case.gd`。
- 场景文件：使用 `snake_case.tscn`。
- 资源文件：使用 `snake_case.tres` 或 `snake_case.res`。
- 类名：使用 `PascalCase`。
- 变量和函数：使用 `snake_case`。
- 常量：使用 `UPPER_SNAKE_CASE`。
- 信号：使用 `snake_case`，表示已完成事件时优先使用过去式含义。

## 脚本结构

优先使用以下顺序：

1. `class_name`。
2. `extends`。
3. 信号。
4. 常量。
5. 导出变量。
6. 公共变量。
7. 私有变量。
8. `@onready` 引用。
9. Godot 生命周期方法。
10. 公共方法。
11. 私有辅助方法。

示例：

```gdscript
class_name ExampleActor
extends CharacterBody2D

signal defeated

const DEFAULT_SPEED: float = 100.0

@export var max_health: float = 10.0

var current_health: float

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
    current_health = max_health

func apply_damage(amount: float) -> void:
    current_health -= amount
    if current_health <= 0.0:
        _defeat()

func _defeat() -> void:
    defeated.emit()
    queue_free()
```

## 类型规则

- 函数应声明返回类型。
- 类型不明显的变量应声明类型。
- 只有在推断结果清晰时才使用 `:=`。
- 除非确实需要弹性类型，否则避免使用 `Variant`。
- 在 Godot 4.x 支持范围内，优先使用类型化数组和字典。

## 节点引用

- 必需子节点引用使用 `@onready`。
- 设计者需要在场景中连接的依赖，使用导出引用或 `NodePath`。
- 避免 `$"../../SomeManager/DeepChild"` 这类脆弱的长路径。
- 避免在高频路径中反复调用 `get_node()`。

## 信号

- 使用信号解耦系统。
- 事件命名应描述已经发生的事情，例如 `health_changed`、`enemy_defeated`、`level_reached` 或 `upgrade_selected`。
- 信号载荷应尽量小，并在可行时使用类型。
- 不要把信号当作清晰归属关系的替代品。

## 数据与平衡

- 不要在脚本中硬编码大型内容表。
- 敌人、武器、升级、波次和掉落优先使用 Godot `Resource` 文件或小型结构化数据文件。
- 不得复制现有商业游戏的数值平衡。
- 对不直观的公式或调校假设进行简短记录。

## 注释

- 谨慎使用注释。
- 注释应解释不明显的决策，而不是解释语法。
- 优先通过清晰命名减少注释需求。

## 错误处理

- 如果缺少导出引用会破坏场景，应在 `_ready()` 中验证。
- 对可恢复的配置问题使用 `push_warning()`。
- 对会阻止正确行为的非法状态使用 `push_error()`。
- 核心玩法系统不要静默失败。

## 性能

- 避免在 `_process()` 和 `_physics_process()` 中产生不必要分配。
- MVP 阶段保持碰撞形状简单。
- 战斗过程中避免昂贵的场景树搜索。
- 只有在性能分析或明显卡顿证明有必要时，才添加对象池。

## UI 代码

- UI 脚本负责展示状态和转发玩家选择。
- UI 脚本不应拥有战斗、刷怪或成长规则。
- HUD 更新尽量由事件驱动。

## 格式

- 使用与 Godot GDScript 编辑器兼容的一致缩进。
- 函数长度应保持容易浏览。
- 当一个脚本开始承担多个系统职责时，应拆分脚本。

## 当前限制

这些风格规则用于未来实现。当前文档阶段不要创建玩家、敌人、武器、升级、拾取物、UI 或地图功能脚本。

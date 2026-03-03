# AtlasDataProcessorPlus 项目介绍
这是一个用 Swift 开发的 macOS 测试数据监控工具，用于实时监控和分析测试平台的数据

## 项目结构
```
AtlasDataProcessorPlus/
├── AtlasDataProcessorPlus/           # 主应用代码
│   ├── Controllers/                 # 控制器层
│   │   ├── MainWindowController.swift
│   │   ├── ChannelViewController.swift
│   │   ├── SummaryViewController.swift
│   │   ├── HistoryWindowController.swift
│   │   └── NSVStackLayout.swift
│   ├── Models/                      # 数据模型层
│   │   ├── Channel.swift
│   │   ├── TestData.swift
│   │   └── AtlasDataProcessor.swift
│   ├── Services/                    # 服务层
│   │   └── DataReaderService.swift
│   ├── AppDelegate.swift           # 应用代理
│   ├── main.swift                   # 入口文件
│   └── ViewController.swift
├── AtlasDataProcessorPlusTests/     # 单元测试
└── testMonitoring.py                # Python版本参考实现
```

## 核心功能
1. 实时数据监控
   - 监控指定路径下的测试数据文件（ /Users/gdlocal/Library/Logs/Atlas/active ）
   - 每10ms检查一次文件变化，确保数据实时性
   - 每5秒扫描一次新通道
  
2. 多通道管理
   - 支持同时监控多个测试通道（格式： group-slot ）
   - 自动发现新通道并创建对应的监控视图
   - 使用标签页（TabView）展示不同通道的详细数据 

3. 数据可视化
   - 汇总视图 ：显示所有通道的统计信息（PASS/FAIL/总数）
   - 详细视图 ：每个通道的详细测试数据表格
   - 支持状态颜色标识（PASS绿色、FAIL红色）
  
## 模块功能详解 
### Models 层
Channel.swift - 通道数据模型

   - 存储通道信息（group、slot、状态、统计数据）
   - 管理测试数据数组，支持最大行数限制
   - 提供PASS/FAIL计数功能
   - 通道状态：等待、运行中、测试结束、已停止

TestData.swift - 测试数据模型
   - 解析CSV格式的测试数据
   - 包含：测试名称、上下限、测量值、单位、状态等字段

AtlasDataProcessor.swift - 数据处理核心
   - 批量处理历史测试数据文件
   - 支持CSV格式数据解析和转换
   - 生成汇总统计信息和失败记录
   - 导出数据为CSV和JSON格式
   - 提供异步处理接口，适合UI应用

Services 层

DataReaderService.swift - 数据读取服务
   - 使用后台线程定时监控文件变化
   - 维护文件读取位置，避免重复读取
   - 自动检测新通道和通道状态变化
   - 通过委托模式通知UI更新 

### Controllers 层
MainWindowController.swift - 主窗口控制器
   - 应用程序主界面管理
   - 控制面板：开始/停止监控、显示设置、清除数据
   - 分割视图：左侧汇总信息 + 右侧通道详情
   - 状态栏显示监控状态
   - 提供历史数据处理窗口入口

ChannelViewController.swift - 通道详情控制器
   - 显示单个通道的详细测试数据表格
   - 支持自动滚动、只显示FAIL行
   - 右键菜单：复制、导出到Excel
   - 根据状态设置行背景色（FAIL行红色高亮）

SummaryViewController.swift - 汇总信息控制器
   - 显示所有通道的统计汇总
   - 双击通道名称可跳转到详细视图
   - 实时更新各通道的PASS/FAIL统计

HistoryWindowController.swift - 历史数据处理控制器
   - 批量处理历史测试数据文件
   - 显示失败记录详情表格
   - 支持导出数据为CSV和JSON格式
   - 提供数据处理进度和统计信息
   - **高级筛选功能**：
     - 点击列标题打开筛选菜单
     - 使用NSPopover显示筛选选项
     - 支持多选筛选值
     - 提供全选/取消全选功能
     - 可调整筛选窗口大小
   - **排序功能**：
     - 支持升序和降序排序
     - 可按任意列进行排序
   - **文件路径操作**：
     - 双击文件路径列打开文件所在位置

### 其他组件
NSVStackLayout.swift - 自定义垂直布局
   - 实现垂直堆叠布局容器
   - 支持间距和边距设置
   
AppDelegate.swift - 应用代理
   - 应用程序入口点
   - 管理主窗口和历史窗口
   - 处理应用生命周期事件

ViewController.swift - 基础视图控制器
   - 应用的基础视图控制器
   - 提供通用视图管理功能

## 使用说明
1. **实时监控模式**：
   - 启动应用后自动开始监控指定路径下的测试数据
   - 可通过控制面板调整显示设置（最大行数、自动滚动、只显示FAIL）
   - 点击通道标签页查看不同通道的详细数据
   - 双击汇总视图中的通道名称快速跳转到对应通道

2. **历史数据处理**：
   - 通过菜单栏或主窗口按钮打开历史数据处理窗口
   - 选择包含测试数据的目录
   - 点击"开始处理"按钮批量处理历史数据
   - 使用筛选功能按列筛选数据
   - 使用排序功能按任意列排序数据
   - 双击文件路径列打开文件所在位置
   - 导出处理结果为CSV或JSON格式

## 功能亮点
1. **实时性**：10ms级别的数据更新，确保测试数据实时显示
2. **多通道**：支持同时监控多个测试通道，自动发现新通道
3. **可视化**：清晰的状态标识和数据展示
4. **灵活性**：可调整的显示设置和筛选排序功能
5. **易用性**：直观的用户界面和操作流程
6. **可扩展性**：模块化设计，易于添加新功能

## 技术架构
- **MVC模式**：清晰的分层设计，分离数据、视图和控制器
- **委托模式**：服务层通过委托通知UI更新
- **后台线程**：数据读取在后台执行，不阻塞UI
- **Auto Layout**：响应式UI布局，适应不同窗口大小
- **NSPopover**：现代的弹出式筛选界面
- **表格视图**：高效的数据展示和交互

## 系统要求
- macOS 10.15或更高版本
- Swift 5.0或更高版本
- Xcode 11.0或更高版本

## 图标参数
16x16 Dock 栏小图标 32x32 Dock 栏图标 128x128 Finder 图标 256x256 大图标 512x512 超大图标

//
//  NSVStackLayout.swift
//  TestMonitorApp
//
//  Created by Your Name on 2026-01-29.
//

import Cocoa

class NSVStackLayout: NSView {
    
    // MARK: - 属性
    
    /// 子视图之间的间距
    var spacing: CGFloat = 0 {
        didSet {
            needsUpdateConstraints = true
        }
    }
    
    /// 内边距
    var edgeInsets: NSEdgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0) {
        didSet {
            needsUpdateConstraints = true
        }
    }
    
    /// 布局方向
    var orientation: NSUserInterfaceLayoutOrientation = .vertical {
        didSet {
            needsUpdateConstraints = true
        }
    }
    
    /// 分布方式
    var distribution: NSStackView.Distribution = .fill {
        didSet {
            needsUpdateConstraints = true
        }
    }
    
    /// 对齐方式
    var alignment: NSLayoutConstraint.Attribute = .leading {
        didSet {
            needsUpdateConstraints = true
        }
    }
    
    /// 保存所有排列的子视图
    private var arrangedSubviews: [NSView] = []
    
    // MARK: - 初始化
    
    convenience init(spacing: CGFloat = 0, edgeInsets: NSEdgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)) {
        self.init(frame: .zero)
        self.spacing = spacing
        self.edgeInsets = edgeInsets  // 这里赋值给类的属性
        self.translatesAutoresizingMaskIntoConstraints = false
    }
    
    // MARK: - 公共方法
    
    /// 添加排列的子视图
    func addArrangedSubview(_ view: NSView) {
        arrangedSubviews.append(view)
        self.addSubview(view)
        
        // 设置视图的自动布局属性
        view.translatesAutoresizingMaskIntoConstraints = false
        
        // 标记需要更新约束
        needsUpdateConstraints = true
    }
    
    /// 移除排列的子视图
    func removeArrangedSubview(_ view: NSView) {
        if let index = arrangedSubviews.firstIndex(of: view) {
            arrangedSubviews.remove(at: index)
            view.removeFromSuperview()
            needsUpdateConstraints = true
        }
    }
    
    /// 获取所有排列的子视图
    func getArrangedSubviews() -> [NSView] {
        return arrangedSubviews
    }
    
    /// 清除所有排列的子视图
    func clearArrangedSubviews() {
        arrangedSubviews.forEach { $0.removeFromSuperview() }
        arrangedSubviews.removeAll()
        needsUpdateConstraints = true
    }
    
    // MARK: - 自动布局
    
    override func updateConstraints() {
        super.updateConstraints()
        
        // 移除旧的约束
        NSLayoutConstraint.deactivate(self.constraints)
        
        guard !arrangedSubviews.isEmpty else { return }
        
        var constraints: [NSLayoutConstraint] = []
        
        if orientation == .vertical {
            // 垂直布局
            
            // 第一个视图的顶部约束
            let firstView = arrangedSubviews[0]
            constraints.append(firstView.topAnchor.constraint(equalTo: self.topAnchor, constant: edgeInsets.top))
            constraints.append(firstView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: edgeInsets.left))
            constraints.append(firstView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -edgeInsets.right))
            
            // 中间视图的垂直约束
            for i in 1..<arrangedSubviews.count {
                let previousView = arrangedSubviews[i - 1]
                let currentView = arrangedSubviews[i]
                
                constraints.append(currentView.topAnchor.constraint(equalTo: previousView.bottomAnchor, constant: spacing))
                constraints.append(currentView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: edgeInsets.left))
                constraints.append(currentView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -edgeInsets.right))
                
                // 如果视图是 NSScrollView，设置其高度
                if currentView is NSScrollView {
                    constraints.append(currentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 200))
                }
            }
            
            // 最后一个视图的底部约束
            let lastView = arrangedSubviews.last!
            constraints.append(lastView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -edgeInsets.bottom))
            
        } else {
            // 水平布局
            let firstView = arrangedSubviews[0]
            constraints.append(firstView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: edgeInsets.left))
            constraints.append(firstView.topAnchor.constraint(equalTo: self.topAnchor, constant: edgeInsets.top))
            constraints.append(firstView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -edgeInsets.bottom))
            
            for i in 1..<arrangedSubviews.count {
                let previousView = arrangedSubviews[i - 1]
                let currentView = arrangedSubviews[i]
                
                constraints.append(currentView.leadingAnchor.constraint(equalTo: previousView.trailingAnchor, constant: spacing))
                constraints.append(currentView.topAnchor.constraint(equalTo: self.topAnchor, constant: edgeInsets.top))
                constraints.append(currentView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -edgeInsets.bottom))
            }
            
            let lastView = arrangedSubviews.last!
            constraints.append(lastView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -edgeInsets.right))
        }
        
        // 根据 distribution 设置约束
        switch distribution {
        case .fillEqually:
            if orientation == .vertical {
                // 垂直等分
                for view in arrangedSubviews {
                    if let firstView = arrangedSubviews.first, view != firstView {
                        constraints.append(view.heightAnchor.constraint(equalTo: firstView.heightAnchor))
                    }
                }
            } else {
                // 水平等分
                for view in arrangedSubviews {
                    if let firstView = arrangedSubviews.first, view != firstView {
                        constraints.append(view.widthAnchor.constraint(equalTo: firstView.widthAnchor))
                    }
                }
            }
        default:
            break
        }
        
        NSLayoutConstraint.activate(constraints)
    }
    
    // MARK: - 布局完成
    
    override func layout() {
        super.layout()
        // 确保视图层级正确
        for (index, view) in arrangedSubviews.enumerated() {
            // 保持正确的 z 轴顺序
            if view.superview != self {
                self.addSubview(view)
            }
        }
    }
}

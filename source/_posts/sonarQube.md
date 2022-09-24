---
title: SonarQube 代码扫描工具
tags:
  - 代码质量
  - c/c++
  - 代码检查工具
categories:
  - 代码扫描工具
date: 2022-09-24 23:40:00
---

# SonarQube 
- 最近工作中，领导一直想让我把部门的代码质量这块的工作搞起来，因为部门里的现在的工程师都是各自为战，代码风格各异，代码的漏洞问题也没有一个统一的工具去检查，甚至有些工程师都不会去做这一块的工作，只有真正出问题的时候才会去重视。
- 我在网上找了一圈，最终确定一款比较好的工具，那就是SonarQube。
## 1、SonarQube
- SonarQube是一款代码质量检测工具，基本版本是开源的，操作简单，支持cppcheck插件，还有web可视化的界面，还支持可持续化基础CI。
- 可以通过配置的代码分析规则，从可靠性、安全性、可维护性、覆盖率、重复率等方面分析项目，风险等级从A~E划分为5个等级。
- sonar设置了质量门，通过设置的质量门评定此次提交分析的项目代码是否达到了规定的要求。

## 2、SonarQube 一般工作流程
- 1、开发人员在其IDE中进行编码，并使用SonarLint运行本地分析。
- 2、开发人员将其代码推送到他们最喜欢的SCM中：git，SVN，TFVC等。
- 3、Continuous Integration Server会触发自动构建，并执行运行SonarQube分析所需的SonarScanner。
- 4、分析报告将发送到SonarQube服务器进行处理。
SonarQube Server处理分析报告结果并将其存储在SonarQube数据库中，并在UI中显示结果。
- 5、开发人员通过SonarQube UI审查，评论，挑战他们的问题，以管理和减少技术债务。
- 6、经理从分析中接收报告。Ops使用API​​自动执行配置并从SonarQube提取数据。运维人员使用JMX监视SonarQube Server。

## 2、SonarQube 实际项目部署
- 待填坑。。。
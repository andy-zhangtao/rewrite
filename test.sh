#!/bin/bash

## 测试模式一
## 如果请求中有指定Header, 则执行Rewrite操作
## 配置参数为:H2?/v1/echo?source=rewrite&source2=kongplugin
## 预期结果:
## {"Accept":["*/*"],"Connection":["keep-alive"],"H2":["dd"],"User-Agent":["curl/7.54.0"],"X-Forwarded-For":["172.17.0.1"],"X-Forwarded-Host":["localhost"],"X-Forwarded-Port":["8000"],"X-Forwarded-Proto":["http"],"X-Real-Ip":["172.17.0.1"]}{"source":["rewrite"],"source2":["kongplugin"]}
curl -H "H2:dd" "http://localhost:8000/_ping"


## 测试模式二
## 如果请求中存在指定Header, 则执行Rewrite操作
## 配置参数为:H2?/v1/echo?source2=mymac&id=2
## 预期结果:
## {"Accept":["*/*"],"Connection":["keep-alive"],"H2":["dd"],"User-Agent":["curl/7.54.0"],"X-Forwarded-For":["172.17.0.1"],"X-Forwarded-Host":["localhost"],"X-Forwarded-Port":["8000"],"X-Forwarded-Proto":["http"],"X-Real-Ip":["172.17.0.1"]}{"id":["2"],"source2":["mymac"]}
curl -H "H2:dd" "http://localhost:8000/_ping?source2=mac"

## 测试模式三
## 如果请求中存在指定Header, 则执行Rewrite操作
## 配置参数为:H2?/v1/{H2}?source=rewrite&header=valeddd
## 预期结果:
## {"Accept":["*/*"],"Connection":["keep-alive"],"H2":["echo"],"User-Agent":["curl/7.54.0"],"X-Forwarded-For":["172.17.0.1"],"X-Forwarded-Host":["localhost"],"X-Forwarded-Port":["8000"],"X-Forwarded-Proto":["http"],"X-Real-Ip":["172.17.0.1"]}{"header":["valeddd"],"source":["rewrite"]}
curl -H "H2:echo" "http://localhost:8000/_ping?source=mac"

## 测试模式四
## 如果请求URL与规则URL直接匹配成功，则执行Rewrite操作
## 配置参数为:/_ping?/v1/echo
## 预期结果:
## {"Accept":["*/*"],"Connection":["keep-alive"],"User-Agent":["curl/7.54.0"],"X-Forwarded-For":["172.17.0.1"],"X-Forwarded-Host":["localhost"],"X-Forwarded-Port":["8000"],"X-Forwarded-Proto":["http"],"X-Real-Ip":["172.17.0.1"]}{"source":["mac"]}
curl "http://localhost:8000/_ping?source=mac"

## 测试模式五
## 动态修改upstream
## 配置参数为:/_ping?domain://tiny-srv-1/v1/test
## 预期结果:
## {"message":"name resolution failed"}
curl "http://localhost:8000/_ping?source=mac"

## 测试模式六
## 对URL应用正则表达式规则生成新URL
## 配置参数为:([^/]+)$?/v1/$1
## 预期结果:
## {"Accept":["*/*"],"Connection":["keep-alive"],"User-Agent":["curl/7.54.0"],"X-Forwarded-For":["172.17.0.1"],"X-Forwarded-Host":["localhost"],"X-Forwarded-Port":["8000"],"X-Forwarded-Proto":["http"],"X-Real-Ip":["172.17.0.1"]}{"source":["mac"]}
curl "http://localhost:8000/echo?source=mac"

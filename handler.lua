--
-- Created by IntelliJ IDEA.
-- User: zhangtao <ztao8607@gmail.com>
-- Date: 2018/1/31
-- Time: 下午1:50
--

local BasePlugin = require "kong.plugins.base_plugin"
local utils = require "kong.tools.utils"
local log = require "kong.cmd.utils.log"
local pl_stringx = require "pl.stringx"
local req_get_headers = ngx.req.get_headers
local ngx_log = ngx.log
local NGX_ERR = ngx.ERR
local NGX_DEBUG = ngx.DEBUG

local RewriteHandler = BasePlugin:extend()
destURL = {}

-- fillURL 填充URL地址
-- 填充规则:
-- 如果URL中存在 {},则视为取特定的Header。 如{X-Dest-URL},则表示取Header X-Dest-URL的值填充此段URL。当没有此Header时，则填充值为空
--
-- 获取填充值的规则:
-- {}必须在同一个Pattern之中视为合法，反之非法。
-- 例如:
--      /{Header1}
--      /{Header1}/
--      均为合法。
-- 而一下则视为非法：
--      /{Header1/}
--      {/Header1}
--      {/Header1}/
local function fillURL(url)
  originURL = url
  urls = utils.split(url, "/")
  for idx, u in pairs(urls) do
    if string.len(u) > 0 then
      prefix = string.find(u, "{")
      suffix = string.find(u, "}")
      if prefix ~= nil and suffix ~= nil and prefix < suffix then
        exHeader = string.sub(u, prefix + 1, suffix - 1)
        if string.len(exHeader) > 0 then
          urls[idx] = req_get_headers()[exHeader]
        else
          urls[idx] = ""
        end
      end
    end
  end

  durl = ""
  for idx, u in pairs(urls) do
    if idx <= table.getn(urls) - 1 then
      durl = durl .. u .. "/"
    else
      durl = durl .. u
    end
  end

  ngx_log(NGX_ERR, "FillURL Origin URL == [" .. originURL .. "] FillURL New URL == [" .. durl .. "]")
  return durl
end


-- checkMethod 判断请求方法是否合法
local function checkMethod(config)

  for _, value in ipairs(config.methods) do
    ngx_log(NGX_ERR, value)
    if value == ngx.req.get_method() then
      return true
    end
  end

  return false
end

-- checkHeader 判断是否包含有切换Header
local function checkHeader(config)
  for _, v in pairs(config.rules) do
    rule = utils.split(v, "?", 2)
    --[[正常情况不应该没有跳转URL,否则就失去了rewrite的意义]]
    if table.getn(rule) == 1 then
      return false
    end

    header = rule[1]

    if req_get_headers()[header] then
      destURL = utils.split(rule[2], "?", 2)
      destURL[1] = fillURL(destURL[1])
      ngx_log(NGX_ERR, destURL)
      return true
    else
      return false
    end
  end
end

-- checkURL 判断是否包含有切换URL
local function checkURL(config)
  originURL = ngx.var.uri
  for _, v in pairs(config.rules) do
    rule = utils.split(v, "?", 2)
    --[[正常情况不应该没有跳转URL,否则就失去了rewrite的意义]]
    if table.getn(rule) == 1 then
      return false
    end

    srcURL = rule[1]

    if pl_stringx.startswith(originURL, srcURL) then
      destURL = utils.split(rule[2], "?", 2)
      destURL[1] = fillURL(destURL[1])
      ngx_log(NGX_ERR, destURL)
      return true
    else
      return false
    end
  end
end


local function needRewrite(config)
  if checkMethod(config) then
    if checkHeader(config) then
      return true
    else if checkURL(config) then
      return true
    else
      return false
    end
    end
  else
    return false
  end
end

function RewriteHandler:new()
  RewriteHandler.super.new(self, "rewrite-plugin")
end

function RewriteHandler:access(config)
  require 'pl.pretty'.dump(config)
  RewriteHandler.super.access(self)
  log("RewriteHandler access")
  ngx_log(NGX_ERR, "===========================")

  if needRewrite(config) then
    local url_args = ngx.req.get_uri_args()
    require 'pl.pretty'.dump(destURL)
    -- 处理Query参数
    if table.getn(destURL) >= 2 then
      query = utils.split(destURL[2], "&")
      for _, value in pairs(query) do
        tquery = utils.split(value, "=")
        url_args[tquery[1]] = tquery[2]
      end
    end

--    if req_get_headers()[header] then
--      ngx.var.upstream_uri = destURL[1]
--    end
    ngx.var.upstream_uri = destURL[1]

    ngx.req.set_uri_args(url_args)
  else
    ngx_log(NGX_ERR, ngx.var.upstream_uri .. " NO MATCH REWRITE RULE Method[" .. ngx.req.get_method() .. "]")
  end

  ngx_log(NGX_DEBUG, require 'pl.pretty'.dump(ngx.var.query_string))
  ngx_log(NGX_DEBUG, ngx.var.upstream_uri)
  ngx_log(NGX_ERR, "===========================")
end

--RewriteHandler.PRIORITY = 100
RewriteHandler.VERSION = "v0.2.1"
return RewriteHandler

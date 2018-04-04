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
upstream = ''

-- reMatch 对URL进行正则匹配
-- url 源请求url
-- re 正则表达式
-- rule 新url规则 例如: /s/$1/echo
-- 返回新生成的url。 如果正则匹配失败，则返回空
local function reMatch(url, re, rule)
    ngx_log(NGX_ERR, "Match URL [" .. url .. "] re [" .. re .. "] rule [" .. rule .. "]")
    newUrl = ""
    local m = ngx.re.match(url, re, "m")
    if m then
        require 'pl.pretty'.dump(m)
        newUrl = rule
        for s in string.gmatch(rule, '$(%d+)') do
            ngx_log(NGX_ERR, "Find Index [" .. s .. "] m[s] [" .. m[s - 1] .. "]")
            newUrl = string.gsub(newUrl, "$" .. s, m[s - 1])
            ngx_log(NGX_ERR, "Find Index [" .. s .. "] newUrl [" .. newUrl .. "]")
        end
    end

    return newUrl
end

-- getUpstream 从url中解析upstream
-- 解析规则:
-- 如果URL以开头 doamin://
-- 则将domain://和后面第一个/之间的值作为upstream
-- 例如domain://tiny-srv/_ping. 提取后的upstream为tiny-srv
local function getUpstream(url)
    if pl_stringx.startswith(url, "domain://") then
        temp_name = string.sub(url, string.len("domain://") + 1, -1)
        temp_upstream = utils.split(temp_name, "/", 2)
        upstream = temp_upstream[1]
        url = string.sub(temp_name, string.len(upstream) + 1, -1)
        ngx_log(NGX_ERR, "New Upsteam [" .. upstream .. "] url [" .. url .. "]")
    end
    return url
end

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
        ngx_log(NGX_ERR, v)
        rule = utils.split(v, "?", 2)
        --[[正常情况不应该没有跳转URL,否则就失去了rewrite的意义]]
        if table.getn(rule) == 1 then
            return false
        end

        header = rule[1]

        if req_get_headers()[header] then
            destURL = utils.split(rule[2], "?", 2)
            destURL[1] = getUpstream(destURL[1])
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
        ngx_log(NGX_ERR, "Compare [" .. originURL .. "] [" .. srcURL .. "]")


        destURL = utils.split(rule[2], "?", 2)
        -- 如果不需要替换upstream,那么destURL[1]仍然为destURL[1]. 所以这里这么做是幂等的
        destURL[1] = getUpstream(destURL[1])

        -- 是否满足直接匹配
        if pl_stringx.startswith(originURL, srcURL) then
            destURL[1] = fillURL(destURL[1])
            ngx_log(NGX_ERR, destURL)
            return true
        end

        -- 是否满足正则匹配
        newUrl = reMatch(originURL, srcURL, destURL[1])
        if (string.len(newUrl) >= 1) then
            destURL[1] = newUrl
            return true
        end
    end
    return false
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
    log(ngx.var.uri)

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

        if string.len(upstream) > 0 then
            ngx.ctx.balancer_address.host = upstream
        end

        ngx.var.upstream_uri = destURL[1]

        ngx.req.set_uri_args(url_args)
    else
        ngx_log(NGX_ERR, ngx.var.uri .. " NO MATCH REWRITE RULE ")
        -- 匹配失败的时候,保留原有的请求URI
        ngx.var.upstream_uri = ngx.var.uri
    end

    ngx_log(NGX_DEBUG, require 'pl.pretty'.dump(ngx.var.query_string))
    ngx_log(NGX_ERR, "----------------------------")
    args = ngx.req.get_query_args()
    ngx_log(NGX_ERR, args['tt'])
    ngx_log(NGX_DEBUG, "origin[" .. ngx.var.uri .. "] rewrite[" .. ngx.var.upstream_uri .. "]")
    ngx_log(NGX_ERR, "===========================")
end

--RewriteHandler.PRIORITY = 100
RewriteHandler.VERSION = "v0.3.2"
return RewriteHandler

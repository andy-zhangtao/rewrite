--
-- Created by IntelliJ IDEA.
-- User: zhangtao <ztao8607@gmail.com>
-- Date: 2018/1/31
-- Time: 下午1:50
--

local BasePlugin = require "kong.plugins.base_plugin"
local utils = require "kong.tools.utils"
local log = require "kong.cmd.utils.log"
local req_get_headers = ngx.req.get_headers
local ngx_log = ngx.log
local NGX_ERR = ngx.ERR
local NGX_DEBUG = ngx.DEBUG

local RewriteHandler = BasePlugin:extend()
local destURL = {}

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
        else
            return false
        end
    else
        return false
    end
end

function RewriteHandler:new()
    RewriteHandler.super.new(self, "rewrite-plugin")
end

function RewriteHandler:access(config)
    RewriteHandler.super.access(self)
    log("RewriteHandler access")
    ngx_log(NGX_ERR, "===========================")
    if needRewrite(config) then
        local url_args = ngx.req.get_uri_args()
        if table.getn(destURL) >= 2 then
            query = utils.split(destURL[2], "&")
            for _, value in pairs(query) do
                tquery = utils.split(value, "=")
                url_args[tquery[1]] = tquery[2]
            end
        end

        if req_get_headers()[header] then
            ngx.var.upstream_uri = destURL[1]
        end
        ngx.req.set_uri_args(url_args)
    else
        ngx_log(NGX_ERR, ngx.var.upstream_uri .. " NO MATCH REWRITE RULE Method[" .. ngx.req.get_method() .. "]")
    end

    ngx_log(NGX_DEBUG, require 'pl.pretty'.dump(ngx.var.query_string))
    ngx_log(NGX_DEBUG, ngx.var.upstream_uri)
    ngx_log(NGX_ERR, "===========================")
end

--RewriteHandler.PRIORITY = 100
RewriteHandler.VERSION = "v0.1.0"
return RewriteHandler
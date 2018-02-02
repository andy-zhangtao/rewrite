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


function RewriteHandler:new()
    RewriteHandler.super.new(self, "rewrite-plugin")
end

function RewriteHandler:access(config)
    RewriteHandler.super.access(self)
    log("RewriteHandler access")
    ngx_log(NGX_ERR, "===========================")
    local url_args = ngx.req.get_uri_args()
    for _, v in pairs(config.rules) do
        rs = utils.split(v, "?", 2)
        header = rs[1]
        destURL = utils.split(rs[2], "?", 2)

        if table.getn(destURL) >= 2 then
            query = utils.split(destURL[2], "&")
            for _, value in pairs(query) do
                tquery = utils.split(value, "=")
                url_args[tquery[1]]=tquery[2]
            end
        end

        if req_get_headers()[header] then
            ngx.var.upstream_uri = destURL[1]
        end
    end
    ngx.req.set_uri_args(url_args)
    ngx_log(NGX_DEBUG, require 'pl.pretty'.dump(ngx.var.query_string))
    ngx_log(NGX_ERR, "===========================")
end

--RewriteHandler.PRIORITY = 100
RewriteHandler.VERSION = "v0.1.0"
return RewriteHandler
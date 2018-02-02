--
-- Created by IntelliJ IDEA.
-- User: zhangtao <ztao8607@gmail.com>
-- Date: 2018/1/31
-- Time: 下午1:53
--

--[[用户自定义匹配规则
-- 当前匹配规则格式为: Header?Dest-Url;
--  Header: 请求Header
--  Dest-URL: Upstream URL
-- 当在请求的Header中存在预定义的header时，将会跳转到Dest-URL
-- ]]
return {
    no_consumer = true,
    fields = {
        methods = {
            type = "array",
            required = true,
        },
        rules = {
            type = "array",
            required = true,
        }
    },
    self_check = check --[[这里应该是个bug, 设定的self_check返回给调用方的是"function"]]
}

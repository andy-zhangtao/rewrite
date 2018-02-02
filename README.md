# Rewrite

插件的设计目的在于对请求进行匹配。 如果符合以下规则，则认为匹配一致:
 * 请求的Method符合预定义Method
 * 请求的Header中包含预定义的Header
 * 请求的URL符合预定义的URL规则
 
如果匹配一致，则将请求重定向到设定的目标Endpoint。
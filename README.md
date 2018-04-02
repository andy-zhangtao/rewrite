# Rewrite


>插件的设计目的在于对请求进行匹配。 如果符合以下规则，则认为匹配一致:
> * 请求的Method符合预定义Method
> * 请求的Header中包含预定义的Header
>如果匹配一致，则将请求重定向到设定的URL。
>此插件不会修改upstream,因此仅仅是修改了源URL。


## Local Dev

使用工程中的dev.sh会创建本地开发环境。 在执行dev.sh之前，需要创建postgres数据库，推荐使用下面的命令来创建:

```docker
docker run -d --name kong-database \
              -p 5432:5432 \
              -e "POSTGRES_USER=kong" \
              -e "POSTGRES_DB=kong" \
              postgres:9.4
```

创建成功之后，执行dev.sh后就会创建local dev 环境。 

如果需要Admin GUI环境，执行以下命令:
```docker
docker run -p 1337:1337 -it --link kong:kong --name konga pantsel/konga
```
当konga当前对于kong 0.12兼容性不太好。 有些功能会报错。 需要配合其它工具使用(curl/postman， etc...)

## Example 1

假设有API /_ping. 在没有启用rewrite plugin之前，其Upstream URL为 http://up1/_ping。 
也就是说，当发起 xxx/_ping请求时，Kong会将此请求路由到http://up1/_ping. 

如果启用rewrite plugin之后，设定如下参数:

```lua
name=rewrite&
config.methods=POSTd&
config.rules=H2?/v1/echo?source=rewrite%26source2=kongplugin
```
上述参数的意思是，当对/_ping发起POST请求后，如果请求Header中存在[H2]，则会将此请求重定向到/v1/echo，并且添加额外的query_string。source=rewrite&source2=kongplugin. 
最终的目标URL为:
```lua
http://up1/v1/echo?source=rewrite&source2=kongplugin
``` 

## Example 2

Rewrite Plugin 会对重名的query_string进行覆盖。假设，源请求为:
```lua
/_ping?soucre2=mymac&id=2
```
rewrite插件会将此请求重定向为: 
```lua
http://up1/v1/echo?soucre2=mymac&id=2&source=rewrite&source2=kongplugin
```

因此最终的source2=kongpluing。 因为Rewrite仅仅是将规则中的query_string附加到源query_string中。 因此这种行为是Openresty/Nginx的行为。

## Example 3 (v0.2.0 添加)

将Header作为变量值，动态生成URL
设置Plugin参数为: 
```lua
H2?/v1/{H2}?source=rewrite&header=valeddd
```
预期结果为:当源请求header中存在H2时，启用Rewrite Plugin。 同时将URL中的{H2}替换为Header中的H2值。 

因此当H2=test时，Rewrite将生成:
```lua
/v1/test?source=rewrite&header=valeddd
```

因此当H2=echo时，Rewrite将生成:
```lua
/v1/echo?source=rewrite&header=valeddd
```

## Example 4 (v0.2.1 添加)

设置Plugin参数为:
```lua
/vm/dd?/v2/m
```
预期结果为: 当源请求URL中以/vm/dd开始时，将此请求的源URL替换为/v2/m。最终的目标URL为:

```lua
源请求:
http://domain/vm/dd
目标请求:
http://domain/v2/m
```

## Example 5 (v0.3.0 添加)
> 动态修改upstream

通过添加`domain://`动态修改upstream

例如设置Plugin参数为: (假设源请求的默认upstream为tiny-srv，当按照下面规则设置后，rewrite将会将源请求修改为 http(s)://tiny-svr-1/v1/test。 tiny-srv-1为其它已存在的upstream名称)
```lua
/_ping?domain://tiny-srv-1/v1/test
```
则源请求为:
```
http://tiny-srv/_ping
```
修改后的目标请求为：
```
http://tiny-srv-1/v1/test
``


# ChangLog

### v0.3.0
* 支持修改upstream名称

### v0.2.1
* 支持URL匹配替换

### v0.2.0
* 支持将Header作为变量组合URL

### v0.1.0
* 支持按照Method，Header规则进行匹配。 
* 支持增加自定义query_string
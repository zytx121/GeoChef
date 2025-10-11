# flutter中使用clustrmaps提供的地球访问量

## 问题1：不显示
https://clustrmaps.com/ 提供了脚本的方式，如
```html
<script type="text/javascript" id="clstr_globe" src="//clustrmaps.com/globe.js?d=aTs2G96jVg3OE7Fi4QsvOITD0NJ63gc2c6HSkUFpnW0"></script>
```
实验发现：`id`不能改，疑似是根据`id`找到script的位置，然后在后面插入自己的节点。所以只要将此script包裹在自己的div中，用`HtmlElementView`就可以显示了

然而仅仅如此，只能看到空白一片，地球没有显示。做了如下实验：
1. 自己写了一个“在指定script后面插入div”的js，发现flutter可以正常显示，说明不是flutter的问题
2. 直接将clustrmaps的script引入自己的html，发现显示正常：地球会旋转
3. 用如下代码运行时注入html：
    ```js
    const script = document.createElement('script');
    script.type = 'text/javascript';
    script.id = 'clstr_globe';
    script.src = 'globe.js';
    document.body.appendChild(script);
    ```
    其中，`globe.js`是本地化的clustrmaps的代码文件。发现出现了和flutter上一样的问题。检查发现dom已经加载了，但是有一个叫做“`clstrm_inner`”的类，其`display`是`none`。强制将其变为`block`，发现地球出现了，但是不会动
4. 在`globe.js`最后的启动函数中加上了console.log，发现均有执行。说明js代码执行正常。

所以，一定是有什么代码负责动画的执行、但没有被运行。而根据实验4，代码能正常执行，说明动画代码应该已经注册，只是没有被触发，而这个触发因素应该是代码之外的。于是只好去排查`globe.js`的代码，发现里面向`$(window).load`注册了回调。这下一切都清楚了：因为这个script是之后加入html的，导致其错过了`window.onload`事件，所以动画不会开始。

验证很简单：在实验3的基础上，控制台执行 `window.dispatchEvent(new Event('load'))` ，发现地球正常了！

所以我写了以下js函数劫持 `$(window).load` ：
```js
// 后续注册到onload的事件会被立即执行
window.addEventListener('load', (e) => {
    const oldAdd = window.addEventListener;
    window.addEventListener = function (type, fn, options) {
        if (type === 'load' && typeof fn === 'function') {
            setTimeout(() => {
                fn.call(window, e);
            }, 0);
        } else {
            oldAdd.call(window, type, fn, options);
        }
    };
});
```

然后就成功了！

## 问题2：尺寸不是自适应的
返回的div的width和height写死了，不会随着后续窗口的变化而变化。

在[WebImage](../../markdown_custom/web_image/web_image_web.dart)中我动态改变了img的width和height，但是此时层层嵌套，里面还有很多div都写死了width和height。所以用了最暴力的方法：css强制缩放。

仅需记录第一次布局的尺寸（请求时是适应父元素尺寸的），之后就可以设置最外层的div的`style.transform`了！
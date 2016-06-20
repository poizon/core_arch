/* Страница */

// required for IE7, #150675
if (window.addEvent) window.addEvent('domready', function() { });

var artEventHelper = {
	'bind': function(obj, evt, fn) {
		if (obj.addEventListener)
			obj.addEventListener(evt, fn, false);
		else if (obj.attachEvent)
			obj.attachEvent('on' + evt, fn);
		else
			obj['on' + evt] = fn;
	}
};

var artUserAgent = navigator.userAgent.toLowerCase();

var artBrowser = {
	version: (artUserAgent.match(/.+(?:rv|it|ra|ie)[\/: ]([\d.]+)/) || [])[1],
	safari: /webkit/.test(artUserAgent) && !/chrome/.test(artUserAgent),
	chrome: /chrome/.test(artUserAgent),
	opera: /opera/.test(artUserAgent),
	msie: /msie/.test(artUserAgent) && !/opera/.test(artUserAgent),
	mozilla: /mozilla/.test(artUserAgent) && !/(compatible|webkit)/.test(artUserAgent)
};
 
artCssHelper = function() {
    var is = function(t) { return (artUserAgent.indexOf(t) != -1) };
    var el = document.getElementsByTagName('html')[0];
    var val = [(!(/opera|webtv/i.test(artUserAgent)) && /msie (\d)/.test(artUserAgent)) ? ('ie ie' + RegExp.$1)
    : is('firefox/2') ? 'gecko firefox2'
    : is('firefox/3') ? 'gecko firefox3'
    : is('gecko/') ? 'gecko'
    : is('chrome/') ? 'chrome'
    : is('opera/9') ? 'opera opera9' : /opera (\d)/.test(artUserAgent) ? 'opera opera' + RegExp.$1
    : is('konqueror') ? 'konqueror'
    : is('applewebkit/') ? 'webkit safari'
    : is('mozilla/') ? 'gecko' : '',
    (is('x11') || is('linux')) ? ' linux'
    : is('mac') ? ' mac'
    : is('win') ? ' win' : ''
    ].join(' ');
    if (!el.className) {
     el.className = val;
    } else {
     var newCl = el.className;
     newCl += (' ' + val);
     el.className = newCl;
    }
} ();

(function() {
    // fix ie blinking
    var m = document.uniqueID && document.compatMode && !window.XMLHttpRequest && document.execCommand;
    try { if (!!m) { m('BackgroundImageCache', false, true); } }
    catch (oh) { };
})();

var artLoadEvent = (function() {
    var list = [];

    var done = false;
    var ready = function() {
        if (done) return;
        done = true;
        for (var i = 0; i < list.length; i++)
            list[i]();
    };

    if (document.addEventListener && !artBrowser.opera)
        document.addEventListener('DOMContentLoaded', ready, false);

    if (artBrowser.msie && window == top) {
        (function() {
            try {
                document.documentElement.doScroll('left');
            } catch (e) {
                setTimeout(arguments.callee, 10);
                return;
            }
            ready();
        })();
    }

    if (artBrowser.opera) {
        document.addEventListener('DOMContentLoaded', function() {
            for (var i = 0; i < document.styleSheets.length; i++) {
                if (document.styleSheets[i].disabled) {
                    setTimeout(arguments.callee, 10);
                    return;
                }
            }
            ready();
        }, false);
    }

    if (artBrowser.safari || artBrowser.chrome) {
        var numStyles;
        (function() {
            if (document.readyState != 'loaded' && document.readyState != 'complete') {
                setTimeout(arguments.callee, 10);
                return;
            }
            if ('undefined' == typeof numStyles) {
                numStyles = document.getElementsByTagName('style').length;
                var links = document.getElementsByTagName('link');
                for (var i = 0; i < links.length; i++) {
                    numStyles += (links[i].getAttribute('rel') == 'stylesheet') ? 1 : 0;
                }
                if (document.styleSheets.length != numStyles) {
                    setTimeout(arguments.callee, 0);
                    return;
                }
            }
            ready();
        })();
    }

    if (!(artBrowser.msie && window != top)) { // required for Blogger Page Elements in IE, #154540
        artEventHelper.bind(window, 'load', ready);
    }
    return ({
        add: function(f) {
            list.push(f);
        }
    })
})();


function artGetElementsByClassName(clsName, parentEle, tagName) {
	var elements = null;
	var found = [];
	var s = String.fromCharCode(92);
	var re = new RegExp('(?:^|' + s + 's+)' + clsName + '(?:$|' + s + 's+)');
	if (!parentEle) parentEle = document;
	if (!tagName) tagName = '*';
	elements = parentEle.getElementsByTagName(tagName);
	if (elements) {
		for (var i = 0; i < elements.length; ++i) {
			if (elements[i].className.search(re) != -1) {
				found[found.length] = elements[i];
			}
		}
	}
	return found;
}

var _artStyleUrlCached = null;
function artGetStyleUrl() {
    if (null == _artStyleUrlCached) {
        var ns;
        _artStyleUrlCached = '';
        ns = document.getElementsByTagName('link');
        for (var i = 0; i < ns.length; i++) {
            var l = ns[i];
            if (l.href && /style\.ie6\.css(\?.*)?$/.test(l.href)) {
                return _artStyleUrlCached = l.href.replace(/style\.ie6\.css(\?.*)?$/, '');
            }
        }

        ns = document.getElementsByTagName('style');
        for (var i = 0; i < ns.length; i++) {
            var matches = new RegExp('import\\s+"([^"]+\\/)style\\.ie6\\.css"').exec(ns[i].innerHTML);
            if (null != matches && matches.length > 0)
                return _artStyleUrlCached = matches[1];
        }
    }
    return _artStyleUrlCached;
}

function artFixPNG(element) {
	if (artBrowser.msie && artBrowser.version < 7) {
		var src;
		if (element.tagName == 'IMG') {
			if (/\.png$/.test(element.src)) {
				src = element.src;
				element.src = artGetStyleUrl() + 'images/spacer.gif';
			}
		}
		else {
			src = element.currentStyle.backgroundImage.match(/url\("(.+\.png)"\)/i);
			if (src) {
				src = src[1];
				element.runtimeStyle.backgroundImage = 'none';
			}
		}
		if (src) element.runtimeStyle.filter = "progid:DXImageTransform.Microsoft.AlphaImageLoader(src='" + src + "')";
	}
}

function artHasClass(el, cls) {
	return (el && el.className && (' ' + el.className + ' ').indexOf(' ' + cls + ' ') != -1);
}

/* Меню */

function artVMenu() {
    var menus = artGetElementsByClassName("art-vmenu", document, "ul");
    for (var k = 0; k < menus.length; k++) {
        var vmenu = menus[k];
        vmenu.uls = vmenu.getElementsByTagName("ul");
        vmenu.items = vmenu.getElementsByTagName("li");
        vmenu.alinks = vmenu.getElementsByTagName("a");
        
        for (var x = 0; x < vmenu.items.length; x++) {
            var li = vmenu.items[x];
            li.className = li.className.replace(/active/, "").replace("  ", " ");
            for (var s = 0; s < li.childNodes.length; s++) {
                var ch = li.childNodes[s];
                if (!(ch && ch.tagName)) continue;
                if (String(ch.tagName).toLowerCase() == "a") {
                    if (ch.href == window.location.href)
                       vmenu.active = li;
                    li.a = ch;
                }
                if (String(ch.tagName).toLowerCase() == "ul") 
                    li.ul = ch;
                ch.className = ch.className.replace(/active/, "").replace("  ", " ");
            }
        }
        if (!vmenu.active) return;
        if (vmenu.active.ul) vmenu.active.ul.className += " active";
        var parent = vmenu.active;
        while (parent && parent != vmenu) {
            parent.className += " active";
            if (parent.a) parent.a.className += " active";
            parent = parent.parentNode;
        }
    }
}

artLoadEvent.add(artVMenu);
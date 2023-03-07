ENV["QT_QUICK_CONTROLS_STYLE"] = "Basic"

using QML

using Qt65Compat_jll
QML.loadqmljll(Qt65Compat_jll)

loadqml("qml/App.qml")

exec()

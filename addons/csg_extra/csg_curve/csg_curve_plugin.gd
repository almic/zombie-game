@tool
extends EditorPlugin


const CSGCurveGizmo = preload('uid://s7s6shug0usc')


var gizmo_plugin: CSGCurveGizmo = CSGCurveGizmo.new()
static var last_selected_nodes: Array[CSGCurvePoint3D]


func _enter_tree():
    add_node_3d_gizmo_plugin(gizmo_plugin)
    EditorInterface.get_selection().selection_changed.connect(update_selected_points)

func _exit_tree():
    remove_node_3d_gizmo_plugin(gizmo_plugin)
    EditorInterface.get_selection().selection_changed.disconnect(update_selected_points)

func update_selected_points() -> void:
    for last_node in last_selected_nodes:
        if is_instance_valid(last_node):
            last_node._show_gizmo = false
            last_node.update_gizmos()
    last_selected_nodes.clear()

    for node in EditorInterface.get_selection().get_top_selected_nodes():
        if is_instance_of(node, CSGCurve3D):
            for child in node.get_children():
                if is_instance_of(child, CSGCurvePoint3D):
                    if child._show_gizmo:
                        continue

                    child._show_gizmo = true
                    child.update_gizmos()
                    last_selected_nodes.append(child)

        elif is_instance_of(node, CSGCurvePoint3D):
            if node._show_gizmo:
                continue

            node._show_gizmo = true
            node.update_gizmos()
            last_selected_nodes.append(node)

            if not is_instance_of(node.get_parent(), CSGCurve3D):
                continue

            for sibling in node.get_parent().get_children():
                if is_instance_of(sibling, CSGCurvePoint3D):
                    if sibling._show_gizmo:
                        continue

                    sibling._show_gizmo = true
                    sibling.update_gizmos()
                    last_selected_nodes.append(sibling)

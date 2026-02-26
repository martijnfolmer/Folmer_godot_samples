extends Node

'''
	We spawn this grid using the Project settings -> globals feature, and initialize
	it in spawn (GridGlobals.grid_state = GridState.new())
	
	Usage :
	var gs := GlobalGrid.grid_state
	if gs:
		# use it
		pass
	
'''

var grid_state: GridState

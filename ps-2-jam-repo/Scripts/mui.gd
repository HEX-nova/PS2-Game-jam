extends CanvasLayer

@onready var Healthbar: TextureProgressBar = $"User Stats/Health bar"
@onready var Healthvalue: Label = $"User Stats/Health value"
@onready var Energybar: TextureProgressBar = $"User Stats/Energy bar"
@onready var Energyvalue: Label = $"User Stats/Energy value"


func _process(delta: float) -> void:
	Healthbar.max_value = GameManager.max_health
	Healthbar.value = GameManager.health
	Energybar.max_value = GameManager.max_energy
	Energybar.value = GameManager.energy
	
	Healthvalue.text = str(round(GameManager.health)) + " / " + str(GameManager.max_health)
	Energyvalue.text = str(round(GameManager.energy)) + " / " + str(GameManager.max_energy)

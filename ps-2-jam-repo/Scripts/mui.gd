extends CanvasLayer

@export_group("Player")
@onready var Healthbar: TextureProgressBar = $"User Stats/Health bar"
@onready var Healthvalue: Label = $"User Stats/Health value"
@onready var Energybar: TextureProgressBar = $"User Stats/Energy bar"
@onready var Energyvalue: Label = $"User Stats/Energy value"

@export_group("Enemies")
@onready var turret_count: Label = $"Remaining enemies/turrets"
@onready var spider_count: Label = $"Remaining enemies/spiders"


func _process(delta: float) -> void:
	Healthbar.max_value = GameManager.max_health
	Healthbar.value = GameManager.health
	Energybar.max_value = GameManager.max_energy
	Energybar.value = GameManager.energy
	
	Healthvalue.text = str(round(GameManager.health)) + " / " + str(GameManager.max_health)
	Energyvalue.text = str(round(GameManager.energy)) + " / " + str(GameManager.max_energy)
	
	turret_count.text = "Remaining Turrets : " + str(GameManager.turrets_left)
	spider_count.text = "Remaining Scorpions : " + str(GameManager.spiders_left)

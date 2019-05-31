# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

#start the measure
class ChangeEnergyUseForKitchen < OpenStudio::Ruleset::ModelUserScript

  #define the name that a user will see
  def name
    return "Change energy use for kitchen"
  end

  # human readable description
  def description
    return "This measure aims to change energy use for kitchen."
  end

  # human readable description of modeling approach
  def modeler_description
    return "Change energy use for kitchen."
  end  
  
  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    #make an argument for LPD
    gas = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('gas',true)
    gas.setDisplayName('Gas Density (W/m2)')
    gas.setDefaultValue(500.0)
    args << gas	
	
    return args
  end #end the arguments method

  #define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    #use the built-in error checking
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    #assign the user inputs to variables
    gas = runner.getDoubleArgumentValue('gas',user_arguments)

   #check the LPD for reasonableness
    if gas < 0 or gas > 5000 #error on impossible values
      runner.registerError("Gas Equipment Energy Use Intensity (W/m^2) must be greater than 0 and less than 5000. You entered #{gas}.")
      return false
    elsif gas > 2000 #warning on unrealistic but possible values
      runner.registerWarning("Gas Equipment Energy Use Intensity of #{gas} W/m^2 seems a little high.  Measure will continue, but double-check this isn't a typo.")
    end	
	
    #create a variable and array for tracking changes to model
    num_spctyp_changed = 0
    spctyp_ch_log = []

    #make changes to the model
    #loop through all space types in the model
    model.getSpaceTypes.each do |space_type|
      num_spctyp_changed += 1 #log change
      runner.registerInfo("Space Type called #{space_type.name}.")
      #loop through all gas equipment in the space type
      space_type.gasEquipment.each do |gas_equip|
        #get the old gas from the existing gas equipment definition, if exists
        old_gas = "not per-area"
        if not gas_equip.gasEquipmentDefinition.wattsperSpaceFloorArea.empty?
          old_gas = gas_equip.gasEquipmentDefinition.wattsperSpaceFloorArea.get
        end
        #add the old and new condition to the change log
        spctyp_ch_log << [space_type.name, old_gas]
        #make a new gas equipment definition
        new_gas_def = OpenStudio::Model::GasEquipmentDefinition.new(model)
        new_gas_def.setWattsperSpaceFloorArea(gas)
        new_gas_def.setName("#{gas} W/m2 gas equipment definition")
        #replace the old gas def with the new gas def
        gas_equip.setGasEquipmentDefinition(new_gas_def)
      end
    end

    #report out the initial and final condition to the user
    initial_condition = ""
    initial_condition << "There are #{num_spctyp_changed} space types."
    final_condition = ""
    spctyp_ch_log.each do |ch|
      initial_condition << "Space type #{ch[0]} had gas of #{ch[1]} W/m2. "
      final_condition << "space type #{ch[0]}, "
    end
    final_condition << "were all set to gas of #{gas} W/m2"
    runner.registerInitialCondition(initial_condition)
    runner.registerFinalCondition(final_condition)

    #report if the measure was Not Applicable
    if num_spctyp_changed == 0
      runner.registerAsNotApplicable("Not Applicable.")
    end

    return true
  end #end the run method

end #end the measure

#boilerplate that allows the measure to be use by the application
ChangeEnergyUseForKitchen.new.registerWithApplication

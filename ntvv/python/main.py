from cimConverter import CIMClass

import os

output_base_path = os.path.abspath(os.path.join('..', 'confidential', 'DSS Export - python'))

equ_base_path = os.path.abspath(os.path.join('..', 'confidential', 'Equipment DB'))
equ_files = [f for f in os.listdir(equ_base_path) if 'csv' == f.split('.')[-1]]

cim_base_path = os.path.abspath(os.path.join('..', 'confidential', 'CIM Export 31_03_2017'))
cim_exports = [f for f in os.listdir(cim_base_path) if 'CIM_Export' in f]

for cim_export in cim_exports:
	output_path = os.path.join(output_base_path, cim_export.replace('CIM_', 'DSS_'))
	xml_files = [f for f in os.listdir(os.path.join(cim_base_path, cim_export)) if 'xml' == f.split('.')[-1]]
	gml_files = [f for f in os.listdir(os.path.join(cim_base_path, cim_export)) if 'gml' == f.split('.')[-1]]

	print(xml_files)
	print(gml_files)
	print(equ_files)

	cim = CIMClass(output_path)

	for xml_file in xml_files:
		xml_path = os.path.join(cim_base_path, cim_export, xml_file)
		cim.add_all_elements(xml_path)

	for gml_file in gml_files:
		gml_path = os.path.join(cim_base_path, cim_export, gml_file)
		cim.add_all_coordinates(gml_path)

	for equ_file in equ_files:
		equ_path = os.path.join(equ_base_path, equ_file)
		cim.add_equipment(equ_path)

	cim.save()
	cim.load()

	cim.save_opendss()

	break
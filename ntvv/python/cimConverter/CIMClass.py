import os
import xml.etree.ElementTree as et
import csv
import re
import math

from cimConverter import logger


class CIMClass:
	"""CIMClass contains all functionality to convert CIM to OpenDSS"""

	_ele = list()
	_output_dir = None
	_equipment = dict()
	_dss_ele = dict()
	_ele_buffers = list()

	def __init__(self, output_dir):
		"""Initialises the CIMClass with logging enabled"""
		self._ele = list()
		self._output_dir = None
		self._equipment = dict()
		self._dss_ele = dict()

		if not os.path.exists(output_dir):
			os.makedirs(output_dir)
		self._output_dir = output_dir

		logger.setup(os.path.join(output_dir, 'CIMClass.log'), )
		logger.info('CIMClass started')

	def save(self):
		"""Saves all data in CIMClass so it can be read in again"""
		# TODO: Implement save() function
		pass

	def load(self, input_path=None):
		"""Loads all data from input file, so that XML, GML & DB need not be loaded again"""
		# TODO: Implement load() functioin
		pass

	def add_all_elements(self, xml_file):
		"""Adds all CIM elements in xml_file"""

		logger.info('adding CIM elements from file: {}'.format(os.path.split(xml_file)[-1]))
		xml_data = et.parse(xml_file)
		rdf_root = xml_data.getroot()

		if rdf_root.tag.split('}')[-1] != 'RDF':
			logger.warning('no RDF element found for file: {}'.format(os.path.split(xml_file)[-1]))
			return

		for rdf_child in rdf_root:
			new_ele = self.get_cim_element(rdf_child)
			if new_ele is not None:
				if new_ele['id'] in [ids['id'] for ids in self._ele]:
					logger.debug('an element ({}) was already imported'.format(new_ele['id']))
					continue
				self._ele.append(new_ele)

	def add_all_coordinates(self, gml_path):
		"""Adds coordinates to the corresponding CIM element"""
		if not os.path.exists(gml_path):
			logger.warning('could not find GML file: {}'.format(gml_path))
			return

		xml_data = et.parse(gml_path)
		nmm_root = xml_data.getroot()

		if nmm_root.tag.split('}')[-1] != 'NMMFeatureCollection':
			logger.warning('no NMMFeatureCollection found for file: {}'.format(gml_path))
			return

		for nmm_data in nmm_root:
			if nmm_data.tag.split('}')[-1] != 'DeviceMember':
				logger.warning('found unidentified NMM element ({}) in: {}'.format(nmm_data, gml_path))
				continue

			nmm_dev = self.get_nmm_device(nmm_data)
			cim_ele = self.get_element_by_id(nmm_dev['id'])
			if cim_ele is None:
				continue
			self._ele.remove(cim_ele)
			cim_ele['coords'] = [float(c) for c in nmm_dev['coords']]
			self._ele.append(cim_ele)

	@staticmethod
	def get_nmm_device(nmm_data):
		if nmm_data[0].tag.split('}')[-1] != 'Device':
			logger.warning('nmm data for {} does not contain a nmm:Device in'.format(nmm_data))
			return

		nmm_data = nmm_data[0]
		nmm_dev = dict()
		for nmm_dev_data in nmm_data:
			tag = nmm_dev_data.tag.split('}')[-1]
			if tag == 'ID':
				nmm_dev['id'] = nmm_dev_data.text
			elif tag == 'NMMGeometry':
				coord_type = None
				for coord_data in nmm_dev_data:
					coord_tag = coord_data.tag.split('}')[-1]
					if coord_tag == 'FieldName':
						coord_type = coord_data.text
					elif coord_type is not None:
						if coord_tag in ['LineString', 'Point']:
							nmm_dev['coords'] = coord_data[0].text.split(' ')
						else:
							logger('no idea how to read coordinates for {}'.format(nmm_data))
		return nmm_dev

	def add_equipment(self, equ_path):
		"""Adds equipment informantion like it is stored in CIM DB"""

		if not os.path.exists(equ_path):
			logger.warning('could not find equipment file: {}'.format(equ_path))
			return

		_, equ_file_name = os.path.split(equ_path)
		equ_name, suffix = equ_file_name.split('.')
		if suffix.lower() != 'csv':
			logger.warning('equipment file is not a CSV file: {}'.format(equ_file_name))
			return

		with open(equ_path, newline='') as equ_file:
			csv_reader = csv.reader(equ_file, delimiter=',')
			header = next(csv_reader)
			# Define the database
			csv_data = dict()
			for data in csv_reader:
				csv_data[data[0]] = dict()
				for i in range(1, len(data)):
					if len(data[i]) == 0:
						continue
					csv_data[data[0]][header[i]] = data[i]
			equ_file.close()

		if equ_name not in self._equipment.keys():
			self._equipment[equ_name] = csv_data
		else:
			for key in csv_data.keys():
				if key not in self._equipment[equ_name]:
					self._equipment[equ_name][key] = csv_data[key]

	@staticmethod
	def get_cim_element(rdf_data):
		"""Analyses and makes a dictionary containing the CIM element data"""
		logger.debug('analysing: {}'.format(rdf_data))

		ele = dict()

		# Get id
		for key in rdf_data.attrib.keys():
			if key.split('}')[-1] == 'ID':
				ele['id'] = rdf_data.attrib[key]
		# Get tag
		ele['tag'] = rdf_data.tag.split('}')[-1]

		# Get data
		for child in rdf_data:
			# Find tag
			tag = child.tag.split('}')[-1]
			if '.' in tag:
				tag = tag.split('.')[-1]
			# tag = tag.lower()

			# Find text for child
			text = child.text
			if text is not None:
				text = text.strip()
			else:
				text = ''
			if len(text) > 0:
				# If text is not empty, add to ele
				if tag in ele.keys():
					logger.warning('tag "{}" already exists for element "{}"'.format(tag, ele['id']))
					continue
				ele[tag] = text
				continue

			# If text is empty, find attributes
			for key in child.attrib.keys():
				if key.split('}')[-1] == 'resource':
					attrib = child.attrib[key].replace('#', '')
					if tag in ele.keys():
						if isinstance(ele[tag], list):
							ele[tag].append(attrib)
						else:
							ele[tag] = [ele[tag], attrib]
					else:
						ele[tag] = attrib

		logger.debug('element details : {}'.format(ele))
		return ele

	def get_element_by_id(self, ele_id, search_eles=None):
		"""Returns the element that matches ID"""
		if search_eles is None:
			search_eles = self._ele
		elif not isinstance(search_eles, list):
			search_eles = self.get_elements_by_tag(search_eles)

		ele = [eles for eles in search_eles if eles['id'] == ele_id]
		if len(ele) == 0:
			logger.warning('no element found for ID: {}'.format(ele_id))
			return None
		elif len(ele) > 1:
			logger.warning('{} elements found for ID: {}'.format(len(ele), ele_id))

		return ele[0]

	def get_elements_by_tag(self, tag_name):
		"""Returns all elements that have matching tag names"""
		return [ele for ele in self._ele if ele['tag'] == tag_name]

	def get_elements_by_resource(self, res_id, search_tag=None):
		"""Returns all elements that contain a resource that matches a resource ID"""
		if search_tag is None:
			search_ele = self._ele
		else:
			search_ele = self.get_elements_by_tag(search_tag)

		def contains_resource(ele, res_id):
			for tag in ele.keys():
				if 'id' is tag:
					continue
				if res_id == ele[tag] or (isinstance(ele[tag], list) and res_id in ele[tag]):
					return True
			return False

		return [ele for ele in search_ele if contains_resource(ele, res_id)]

	def remove_elements_from_set(self, remove_eles, search_eles=None):
		"""Only returns a set of search elements that do not contain a certain set of elements (i.e. remove_eles) """
		if search_eles is None:
			search_eles = self._ele

		return [ele for ele in search_eles if ele['id'] not in [bad['id'] for bad in remove_eles]]

	def save_opendss(self):
		# Clear all saved DSS elements
		self._dss_ele = dict()

		# Remove all OpenDSS files in output
		for file_name in os.listdir(self._output_dir):
			if file_name.split('.')[-1].lower() == 'dss':
				os.remove(os.path.join(self._output_dir, file_name))

		# To begin converting, find the substation
		ss = self.get_elements_by_tag('Substation')
		if len(ss) == 0:
			logger.error('no substation found')
			return
		elif len(ss) > 1:
			logger.warning('{} substations found'.format(len(ss)))
		ss = ss[0]

		# Find connectivity node that belongs to substation (i.e. root node)
		ss_cn = self.get_elements_by_resource(ss['id'], 'ConnectivityNode')
		if len(ss_cn) != 1:
			logger.error('{} connectivity nodes found for substation'.format(len(ss_cn)))
			return
		ss_cn = ss_cn[0]

		# Write the beginning of the master file
		f = open(os.path.join(self._output_dir, 'master.dss'), 'w')
		f.write('Clear\n\n')
		f.write('Set DefaultBaseFrequency=50.0\n\n')
		f.write('New Circuit.{}\n\n'.format(ss['name'].replace(' ', '_')))
		f.write('Edit Vsource.Source Bus1={} BasekV=11.0 Frequency=50.0\n\n'.format(ss_cn['name']))
		f.close()

		# Start the network parsing process
		cn_list = [ss_cn]
		cn_old = list()

		terminal_list = list()
		terminal_old = list()

		saved_equipment = list()

		logger.debug(10*'-' + ' PARSING ' + 10*'-')

		while len(cn_list) > 0:
			cn_next = cn_list.pop()
			cn_old.append(cn_next)

			terminal_new = self.get_elements_by_resource(cn_next['id'], 'Terminal')
			terminal_new = self.remove_elements_from_set(terminal_old, terminal_new)
			terminal_list += terminal_new

			while len(terminal_list) > 0:
				terminal_next = terminal_list.pop()
				terminal_old.append(terminal_next)

				# Find the conducting equipment
				equipment = self.get_element_by_id(terminal_next['ConductingEquipment'])
				cn_new, terminal_equipment = self.save_opendss_for_equipment(equipment)

				# Make sure we ignore the terminals from the passed equipment
				terminal_equipment = self.remove_elements_from_set(terminal_old, terminal_equipment)
				terminal_old += terminal_equipment

				# Make sure we only carry on with connectivity nodes that we have not already seen
				cn_new = self.remove_elements_from_set(cn_old, cn_new)
				cn_list += cn_new

		logger.debug(10 * '-' + ' PARSING DONE ' + 10 * '-')

		# Finish by adding all files to master
		f = open(os.path.join(self._output_dir, 'master.dss'), 'a')
		f.close()

	def _get_terminals(self, equipment):
		terminals = self.get_elements_by_resource(equipment['id'], 'Terminal')
		cn_ids = [t['ConnectivityNode'] for t in terminals]
		sequence = [int(t['sequenceNumber']) - 1 for t in terminals]
		terminals = [terminals[i] for i in sequence]
		cn = [self.get_element_by_id(ele_id) for ele_id in cn_ids]
		return cn, terminals

	def _save_new_dss_transformer(self, dss):
		if 'transformer' not in self._dss_ele.keys():
			self._dss_ele['transformer'] = list()
		self._dss_ele['transformer'].append(dss['id'])

		dss['txfrmr_name'] = 'txfrmr_' + str(len(self._dss_ele['transformer']))
		with open(os.path.join(self._output_dir, 'transformers.dss'), 'a') as f:
			f.write('new Transformer.{} windings={} xhl={} basefreq={} sub={}\n'.format(
				dss['txfrmr_name'], dss['txfrmr_windings'], dss['txfrmr_xhl'], dss['txfrmr_basefreq'], dss['txfrmr_sub']
			))
			for i in range(dss['txfrmr_windings']):
				dss['wdg_bus'][i] += '.1.2.3'
				if dss['wdg_conn'][i] in ['w', 'wye']:
					dss['wdg_bus'][i] += '.0'
				f.write(' ~ Wdg={} Bus={} Conn={} Kv={} Kva={} rneut={} xneut={}\n'.format(
					i, dss['wdg_bus'][i], dss['wdg_conn'][i], dss['wdg_kv'][i], dss['wdg_kva'][i], dss['wdg_rneut'][i],
					dss['wdg_xneut'][i]
				))
			f.close()

	def _save_new_dss_line(self, dss):
		# Before saving the line, save the linecode
		if 'linecode' not in self._dss_ele.keys():
			self._dss_ele['linecode'] = list()

		# Fix the linecode so that OpenDSS can use it
		dss['line_linecode_fixed'] = re.sub('[^0-9a-zA-Z]+', '_', dss['line_linecode'])
		if dss['line_linecode_fixed'] not in self._dss_ele['linecode']:

			linecode = dict()
			linecode['name'] = dss['line_linecode_fixed']
			if 'cable' in self._equipment.keys() and dss['line_linecode'] in self._equipment['cable']:
				linecode_info = self._equipment['cable'][dss['line_linecode']]
				linecode['r1'] = linecode_info['PositiveSequenceResistance']
				linecode['x1'] = linecode_info['PositiveSequenceReactance']
				linecode['r0'] = linecode_info['ZeroSequenceResistance']
				linecode['x0'] = linecode_info['ZeroSequenceReactance']
				linecode['normamps'] = linecode_info['NominalRating']
				linecode['emergamps'] = linecode_info['FourthRating']
			elif 'overhead' in self._equipment.keys() and dss['line_linecode'] in self._equipment['overhead']:
				linecode_info = self._equipment['overhead'][dss['line_linecode']]
				# linecode['r1'] = linecode_info[]
				# linecode['x1'] = linecode_info[]
				# linecode['r0'] = linecode_info[]
				# linecode['x0'] = linecode_info[]
				# linecode['normamps'] = linecode_info[]
				# linecode['emergamps'] = linecode_info[]
			else:
				logger.warning('linecode {} not found, so I\'m using default instead'.format(dss['line_linecode']))
				linecode['r1'] = 0.4
				linecode['x1'] = 1.4
				linecode['r0'] = 0.4
				linecode['x0'] = 1.4
				linecode['normamps'] = 100
				linecode['emergamps'] = 120

			linecode['units'] = 'km'
			linecode['basefreq'] = 50.0
			linecode['nphases'] = 3

			with open(os.path.join(self._output_dir, 'linecode.dss'), 'a') as f:
				f.write('New Linecode.{} Nphases={} R1={} X1={} R0={} X0={} Units={} BaseFreq={} Normamps={} Emergamps={}\n'.format(
					linecode['name'], linecode['nphases'], linecode['r1'], linecode['x1'], linecode['r0'], linecode['x0'],
					linecode['units'], linecode['basefreq'], linecode['normamps'], linecode['emergamps']
				))
				f.close()
			self._dss_ele['linecode'].append(dss['line_linecode_fixed'])

		# Save the line itself
		if 'line' not in self._dss_ele.keys():
			self._dss_ele['line'] = list()
		self._dss_ele['line'].append(dss['id'])

		dss['line_name'] = 'line_' + str(len(self._dss_ele['line']))
		with open(os.path.join(self._output_dir, 'lines.dss'), 'a') as f:
			f.write('new Line.{} bus1={} bus2={} Linecode={} Length={} Phases={} Units={}\n'.format(
				dss['line_name'], dss['line_bus'][0], dss['line_bus'][1], dss['line_linecode_fixed'],
				dss['line_length'], dss['line_phases'], dss['line_units']
			))
			f.close()

	def _save_new_dss_load(self, dss):
		if 'load' not in self._dss_ele.keys():
			self._dss_ele['load'] = list()
		self._dss_ele['load'].append(dss['id'])

		# Get sequential load name
		dss['load_name'] = 'load_' + str(len(self._dss_ele['load']))
		# Convert phases into proper bus suffix
		dss['load_phases'] = dss['load_phases'].split('.')[-1]
		dss['load_phases'] = dss['load_phases'].replace('A', '.1')
		dss['load_phases'] = dss['load_phases'].replace('B', '.2')
		dss['load_phases'] = dss['load_phases'].replace('C', '.3')
		dss['load_phases'] = dss['load_phases'].replace('N', '.0')

		phase_count = sum(p == '.' for p in dss['load_phases'][1:])
		if phase_count == 1:
			# Single phase load -> add once
			dss['load_bus'] += dss['load_phases']
			dss['load_phases'] = phase_count
			with open(os.path.join(self._output_dir, 'loads.dss'), 'a') as f:
				f.write('New Load.{} bus1={} Phases={} Kv={} Kw={} Pf={} Model={}\n'.format(
					dss['load_name'], dss['load_bus'], dss['load_phases'], dss['load_voltage'],
					dss['load_power'], dss['load_pf'], dss['load_model']
				))
				f.close()

		elif phase_count == 3:
			# Three phase load -> add three single phase loads
			load_phases = 1
			for p in range(phase_count):
				load_name = dss['load_name'] + '_' + str(p+1)
				load_bus = dss['load_bus'] + '.' + str(p+1) + '.0'
				with open(os.path.join(self._output_dir, 'loads.dss'), 'a') as f:
					f.write('New Load.{} bus1={} Phases={} Kv={} Kw={} Pf={} Model={}\n'.format(
						load_name, load_bus, load_phases, dss['load_voltage'],
						dss['load_power'], dss['load_pf'], dss['load_model']
					))
					f.close()
		else:
			logger.error('do not know what to do for {} phases of {}'.format(phase_count, dss['id']))


	def _save_new_dss_coordinates(self, buses, coords):
		if 'buses' not in self._dss_ele.keys():
			self._dss_ele['buses'] = list()
		for i in range(len(buses)):
			if buses[i] in self._dss_ele['buses']:
				continue

			if len(buses) * 2 != len(coords):
				logger.error('number of buses and coordinates do not match ({} != {})'.format(len(buses), len(coords) // 2))
				continue
			with open(os.path.join(self._output_dir, 'buscoords.dss'), 'a') as f:
				f.write('{}, {:.10f}, {:.10f}\n'.format(buses[i], coords[i*2], coords[i*2+1]))
				f.close()
			self._dss_ele['buses'].append(buses[i])

	def save_opendss_for_equipment(self, equipment):
		logger.info('saving equipment: {}'.format(equipment['id']))

		cn, terminals = self._get_terminals(equipment)

		# TODO: Convert the equipment to OpenDSS
		if equipment['tag'] == 'PowerTransformer':

			# Find transformer asset
			txfrmr_asset = self.get_elements_by_resource(equipment['id'], 'Asset')
			if len(txfrmr_asset) == 0:
				logger.error('transformer ({}) has no asset'.format(equipment['id']))
				return cn, terminals
			elif len(txfrmr_asset) > 1:
				logger.warning('{} assets found for transformer ({})'.format(len(txfrmr_asset), equipment['id']))
			txfrmr_asset = txfrmr_asset[0]

			# Find transformer information
			txfrmr_info = self.get_element_by_id(txfrmr_asset['AssetInfo'])
			if txfrmr_info is None:
				logger.error('cannot find information for transforemer asset {}'.format(txfrmr_asset['AssetInfo']))
				return cn, terminals

			# Populate dss and save
			dss = dict()
			if 'transformer' in self._equipment.keys() and txfrmr_info['name'] in self._equipment['transformer']:
				txfrmr_info = self._equipment['transformer'][txfrmr_info['name']]
				dss['wdg_kv'] = [float(txfrmr_info['PrimaryVoltageKVLL']), float(txfrmr_info['SecondaryVoltageKVLL'])]
				dss['wdg_kva'] = [float(txfrmr_info['NominalRatingKVA']), float(txfrmr_info['NominalRatingKVA'])]
				dss['wdg_conn'] = ['delta', 'wye']
				dss['wdg_rneut'] = [float(txfrmr_info['PrimGroundingResistanceOhms']), float(txfrmr_info['SecGroundingResistanceOhms'])]
				dss['wdg_xneut'] = [float(txfrmr_info['PrimGroundingReactanceOhms']), float(txfrmr_info['SecGroundingReactanceOhms'])]
				dss['txfrmr_xhl'] = float(txfrmr_info['XR0Ratio'])
			else:
				dss['wdg_kv'] = [11.0, 0.4]
				dss['wdg_kva'] = [500.0, 500.0]
				dss['wdg_conn'] = ['delta', 'wye']
				dss['wdg_rneut'] = [0.0, 0.0]
				dss['wdg_xneut'] = [0.0, 0.0]
				dss['txfrmr_xhl'] = 8.0

			dss['id'] = equipment['id']
			dss['wdg_bus'] = [c['id'] for c in cn]
			dss['txfrmr_windings'] = 2
			dss['txfrmr_basefreq'] = 50.0
			dss['txfrmr_sub'] = 'y'

			self._save_new_dss_transformer(dss)

		elif equipment['tag'] in ['BusbarSection', 'Disconnector', 'Fuse', 'LoadBreakSwitch']:

			# Make a dummy line element
			dss = dict()
			dss['id'] = equipment['id']
			dss['line_bus'] = [c['id'] for c in cn]
			dss['line_length'] = 1e-4
			dss['line_linecode'] = 'DEFAULT'
			dss['line_phases'] = 3
			dss['line_units'] = 'm'

			self._save_new_dss_line(dss)
			if 'coords' in equipment.keys() and len(equipment['coords']) == 2 * len(dss['line_bus']):
				self._save_new_dss_coordinates(dss['line_bus'], equipment['coords'])
		elif equipment['tag'] == 'ACLineSegment':

			# Get line asset
			line_asset = self.get_elements_by_resource(equipment['id'], 'Asset')

			dss = dict()
			dss['id'] = equipment['id']
			dss['line_bus'] = [c['id'] for c in cn]
			dss['line_phases'] = 3
			dss['line_units'] = 'm'

			# Check if it's overhead (boken into wires) or underground (single cable)
			if equipment['PSRType'] == 'PSRType_Overhead':
				if len(line_asset) != 2 and len(line_asset) != 4:
					logger.warning('found {} assets overhead wire {}'.format(len(line_asset), equipment['id']))
					dss['line_linecode'] = 'DEFAULT'
				else:
					wire_info = self.get_element_by_id(line_asset[0]['AssetInfo'], 'OverheadWireInfo')
					dss['line_linecode'] = wire_info['name']
			elif equipment['PSRType'] == 'PSRType_Underground':
				if len(line_asset) != 1:
					logger.warning('found {} assets for underground cable {}'.format(len(line_asset), equipment['id']))
					dss['line_linecode'] = 'DEFAULT'
				else:
					cable_info = self.get_element_by_id(line_asset[0]['AssetInfo'], 'CableInfo')
					dss['line_linecode'] = cable_info['name']
			else:
				logger.warning('unknown PSRType {}'.format(equipment['PSRType']))
				dss['line_linecode'] = 'DEFAULT'

			# Populate length correctly
			dss['line_length'] = equipment['length']
			if 'coords' in equipment.keys():
				# Break into indicidual lines
				line_length_orginal = dss['line_length']
				line_bus_original = dss['line_bus'].copy()

				length_scales = list()
				length_scales_sum = 0.0
				c = equipment['coords']
				for i in range(2, len(c), 2):
					length_scales.append(math.sqrt(math.pow(c[i]-c[i-2], 2) + math.pow(c[i+1]-c[i-1], 2)))
					length_scales_sum += length_scales[-1]

				for i in range(len(length_scales)):
					length_scales[i] /= length_scales_sum

				for i in range(len(length_scales)):
					if i == 0:
						dss['line_bus'][0] = line_bus_original[0]
					else:
						dss['line_bus'][0] = line_bus_original[0] + '_' + str(i)

					if i == len(length_scales) - 1:
						dss['line_bus'][1] = line_bus_original[1]
					else:
						dss['line_bus'][1] = line_bus_original[0] + '_' + str(i+1)

					dss['line_length'] = float(line_length_orginal) * length_scales[i]
					self._save_new_dss_line(dss)
					self._save_new_dss_coordinates(dss['line_bus'], c[i*2:i*2+4])
			else:
				self._save_new_dss_line(dss)

		elif equipment['tag'] == 'EnergyConsumer':

			# Get information
			dss = dict()
			dss['id'] = equipment['id']
			dss['load_name'] = equipment['name']
			dss['load_bus'] = cn[0]['id']
			dss['load_phases'] = terminals[0]['phases']
			dss['load_power'] = 1.0
			dss['load_voltage'] = 0.23
			dss['load_pf'] = 0.95
			dss['load_model'] = 1

			self._save_new_dss_load(dss)
			if 'coords' in equipment.keys():
				self._save_new_dss_coordinates(dss['load_bus'], equipment['coords'])

		elif equipment['tag'] in ['EnergyServicePoint']:

			# All things that need not be used in OpenDSS
			pass

		else:

			# If an element has not yet been defined, flag it up and update code
			logger.warning('element {} not yet implemented'.format(equipment['tag']))
			
		return cn, terminals
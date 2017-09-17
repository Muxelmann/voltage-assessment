import os
import xml.etree.ElementTree as et

from cimConverter import logger


class CIMClass:
	"""CIMClass contains all functionality to convert CIM to OpenDSS"""

	_ele = []
	_output_dir = None
	_equipment = []
	_dss_ele = []
	_ele_buffers = []

	def __init__(self, output_dir):
		"""Initialises the CIMClass with logging enabled"""
		self._ele = []
		self._output_dir = None
		self._equipment = []
		self._dss_ele = []

		if not os.path.exists(output_dir):
			os.makedirs(output_dir)
		self._output_dir = output_dir

		logger.setup(os.path.join(output_dir, 'CIMClass.log'), )
		logger.info('CIMClass started')

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
					logger.warning('an element ({}) was already imported'.format(new_ele['id']))
					continue
				self._ele.append(new_ele)

	@staticmethod
	def get_cim_element(rdf_data):
		"""Analyses and makes a dictionary containing the CIM element data"""
		logger.debug('analysing: {}'.format(rdf_data))

		ele = {}

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

		ele = [eles for eles in search_eles if eles['id'] == ele_id]
		if len(ele) == 0:
			logger.warning('no element found for ID: {}'.format(ele_id))
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
		self._dss_ele = []

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
		cn_old = []

		terminal_list = []
		terminal_old = []

		saved_equipment = []

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

	def save_opendss_for_equipment(self, equipment):
		logger.info('saving equipment: {}'.format(equipment['id']))

		def get_terminals(self, equipment):
			terminals = self.get_elements_by_resource(equipment['id'], 'Terminal')
			cn_ids = [t['ConnectivityNode'] for t in terminals]
			sequence = [int(t['sequenceNumber'])-1 for t in terminals]
			terminals = [terminals[i] for i in sequence]
			cn = [self.get_element_by_id(ele_id) for ele_id in cn_ids]
			return cn, terminals

		return get_terminals(self, equipment)
#!/usr/bin/env nu
use std

# This record stores all supported terraform resources. Record structure is as follows:
# Record key is the terraform resource name
# Record value contains two keys, first is the fields record that contains all resource fields and their types that are necessary for import
# Identifier is a closure that generates the import command that is passed together with the resource address to terraform import
let resources_map = {
    aws_iam_role_policy_attachment: {
        fields: {
            role: string
            policy_arn: string
        }
        identifier: {|resource|
            $"($resource.values.role)/($resource.values.policy_arn)"
        }
    }
    aws_route_table_association: {
        fields: {
            subnet_id: string
            route_table_id: string
        }
        identifier: {|resource|
            $"($resource.values.subnet_id)/($resource.values.route_table_id)"
        }
    }
    aws_security_group_rule: {
        fields: {
            security_group_id: string

        }
        identifier: {|resource|
            [$resource.security_group_id,
                $resource.values.type,
                $resource.values.protocol,
                $resource.values.from_port,
                $resource.values.to_port,
                (if $resource.values.self {'self'} else {null}),
                (if ($resource.values.cidr_blocks?|length) > 0 {$resource.values.cidr_blocks} else {null})
            ]
            | compact
            | flatten
            | str join '_'
        }
    }
    aws_route53_record: {
        fields: {
            name: string
            type: string
            zone_id: string
        }
        identifier: {|resource|
            $"($resource.zone_id)_($resource.name)_($resource.type)"
        }
    }
    aws_db_instance: {
        fields: {
            identifier: string
        }
        identifier: {|resource|
            $resource.values.identifier
        }
    }
    aws_cloudwatch_log_group: {
        fields: {
            name: string
        }
        identifier: {|resource|
            $resource.values.name
        }
    }
    aws_elasticache_replication_group: {
        fields: {
            replication_group_id: string
        }
        identifier: {|resource|
            $resource.values.replication_group_id
        }
    }
    aws_route53_zone: {
        fields: {
            name: string
        }
        identifier: {|resource|
            aws route53 list-hosted-zones --output json
            | from json
            | get HostedZones
            | where Name == $"($resource.values.name)."
            | get 0.Id
            | split column -c '/'
            | get 0.column2
        }
    }
    aws_iam_role_policy: {
        fields: {
            role: string
            name: string
        }
        identifier: {|resource|
            $"($resource.values.role):($resource.values.name)"
        }
    }
    aws_iam_instance_profile: {
        fields: {
            name_prefix: string
        }
        identifier: {|resource|
            aws iam list-instance-profiles --output json
            | from json
            | get InstanceProfiles
            | where InstanceProfileName starts-with ($resource.values.name_prefix|str replace -a '_' '-')
            | get 0.InstanceProfileName
        }
    }
    aws_acm_certificate: {
        fields: {
            domain_name: string
        }
        identifier: {|resource|
            aws acm list-certificates --output json
            | from json
            | get CertificateSummaryList
            | where DomainName == $resource.values.domain_name
            | get 0.CertificateArn
        }
    }
    aws_iam_role: {
        fields: {
            name_prefix: string
        }
        identifier: {|resource|
            aws iam list-roles --output json
            | from json
            | get Roles
            | where RoleName starts-with ($resource.values.name_prefix|str replace -a '_' '-')
            | get RoleName.0
        }
    }
    aws_lb_target_group: {
        fields: {
            name: string
        }
        identifier: {|resource|
            aws elbv2 describe-target-groups --output json
            | from json
            | get TargetGroups
            | where TargetGroupName == $resource.values.name
            | get 0.TargetGroupArn
        }
    }
    aws_vpc: {
        fields: {
            cidr_block: string
        }
        identifier: {|resource|
            aws ec2 describe-vpcs --output json
            | from json
            | get Vpcs
            | where CidrBlock == $resource.values.cidr_block
            | get 0.VpcId
        }
    }
    aws_subnet: {
        fields: {
            cidr_block: string
        }
        identifier: {|resource|
        aws ec2 describe-subnets --output json
        | from json
        | get Subnets
        | where CidrBlock == $resource.values.cidr_block
        | get 0.SubnetId
        }
    }
    aws_lb: {
        fields: {
            name: string
        }
        identifier: {|resource|
            aws elbv2 describe-load-balancers --output json
            | from json
            | get LoadBalancers
            | where LoadBalancerName == $resource.values.name
            | get 0.LoadBalancerArn
        }
    }
    aws_lb_listener: {
        fields: {
            load_balancer_arn: string
            port: int
        }
        identifier: {|resource|
            aws elbv2 describe-listeners --load-balancer-arn $resource.values.load_balancer_arn --output json
            | from json
            | get Listeners
            | where Port == $resource.values.port
            | get 0.ListenerArn
        }
    }
    aws_autoscaling_group: {
        fields: {
            name: string
        }
        identifier: {|resource|
            $resource.values.name
        }
    }
    aws_launch_template: {
        fields: {
            name: string
        }
        identifier: {|resource|
            aws ec2 describe-launch-templates --output json
            | from json
            | get LaunchTemplates
            | where LaunchTemplateName == $resource.values.name
            | get 0.LaunchTemplateId
        }
    }
    aws_iam_user: {
        fields: {
            name: string
        }
        identifier: {|resource|
            $resource.values.name
        }
    }
    aws_iam_user_group_membership: {
        fields: {
            user: string
            groups: list<string>
        }
        identifier: {|resource|
            [$resource.values.user $resource.values.groups]
            | flatten
            | str join '/'
        }
    }
    aws_network_acl_rule: {
        fields: {
            network_acl_id: string
        }
        identifier: {|resource|
            [
                $resource.values.network_acl_id,
                $resource.values.rule_number,
                $resource.values.protocol,
                $resource.values.egress
            ]| str join ':'
        }
    }
    aws_route: {
        fields: {
            route_table_id: string
        }
        identifier: {|resource|
            [
                $resource.values.route_table_id,
                ($resource.values.destination_cidr_block?|default $resource.values.destination_ipv6_cidr_block)
            ] | str join '_'
        }
    }
    aws_network_acl: {
        fields: {
            subnet_ids: list<string>
        }
        identifier: {|resource|
            aws ec2 describe-network-acls --output json
            | from json
            | get NetworkAcls
            | filter {|x| $x.Associations.SubnetId | any {|y| $y in $resource.values.subnet_ids }}
            | get 0.NetworkAclId
        }
    }
    aws_default_network_acl: {
        fields: {
            default_network_acl_id: string
        }
        identifier: {|resource|
            $resource.values.default_network_acl_id
        }
    }
    aws_default_route_table: {
        fields: {
            vpc_id: string
        }
        identifier: {|resource|
            $resource.values.vpc_id
        }
    }
    aws_instance: {
        fields: {}
        identifier: {|resource|
            aws ec2 describe-instances --output json
            | from json
            | get Reservations.Instances
            | flatten
            | update-tags
            | where Tags.Name == $resource.values.tags.Name
            | get 0.InstanceId
        }
    }
    aws_security_group: {
        fields: {
            description: string
            vpc_id: string
        }
        identifier: {|resource|
            aws ec2 describe-security-groups --output json
            | from json
            | get SecurityGroups
            | where Description == $resource.values.description and VpcId == $resource.values.vpc_id
            | get 0.GroupId
        }
    }
    aws_nat_gateway: {
        fields: {}
        identifier: {|resource|
            aws ec2 describe-nat-gateways --output json
            | from json
            | get NatGateways
            | update-tags
            | where Tags.Name == $resource.values.tags.Name
            | get 0.NatGatewayId
        }
    }
    aws_internet_gateway: {
        fields: {}
        identifier: {|resource|
            aws ec2 describe-internet-gateways --output json
            | from json
            | get InternetGateways
            | update-tags
            | where Tags.Name == $resource.values.tags.Name
            | get 0.InternetGatewayId
        }
    }
    aws_eip: {
        fields: {}
        identifier: {|resource|
            aws ec2 describe-addresses --output json
            | from json
            | get Addresses
            | update-tags
            | where Tags.Name == $resource.values.tags.Name
            | get 0.AllocationId
        }
    }
    aws_route_table: {
        fields: {}
        identifier: {|resource|
            aws ec2 describe-route-tables --output json
            | from json
            | get RouteTables
            | update-tags
            | where Tags.Name == $resource.values.tags.Name
            | get 0.RouteTableId
        }
    }
    aws_egress_only_internet_gateway: {
        fields: {}
        identifier: {|resource|
            aws ec2 describe-egress-only-internet-gateways --output json
            | from json
            | get EgressOnlyInternetGateways
            | update-tags
            | where Tags.Name == $resource.values.tags.Name
            | get 0.EgressOnlyInternetGatewayId
        }
    }
    aws_vpc_peering_connection_accepter: {
        fields: {
            vpc_peering_connection_id: string
        }
        identifier: {|resource|
            $resource.values.vpc_peering_connection_id
        }
    }
    aws_flow_log: {
        fields: {
            vpc_id: string
        }
        identifier: {|resource|
            aws ec2 describe-flow-logs --output json
            | from json
            | get FlowLogs
            | where ResourceId == $resource.values.vpc_id
            | get 0.FlowLogId
        }
    }
}

def update-tags [] {
    update Tags {
        transpose -i -r -d
        | default '' Name
    }
}

# returns the values field of resource record actual values replaced with their basic types
# The reason records, tables and lists get simplified is because nested types change depending on whether the field is empty
# e.g a non-empty list will be described as list<string> while an empty one will be a list<any>
def get-resource-types [
    resource: record<resource_type: string, address: string, values: record>
] record<resource_type: string, address: string, values: record> -> record {
    $resource.values
    | transpose key value
    | insert type {|x|
        $x.value
        | describe --no-collect
        | split row '<'
        | get 0
    }
    | reject value
    | transpose -i -r -d
}

# recursively gather resources from both root terraform module and all of its submodules
def get-resources [
    module: record
] record -> table<resource_type: string, address: string, values: record> {
    mut resources = []

    if 'resources' in ($module|columns) {
        $resources ++= (
            $module.resources
            | select type address values
            | rename resource_type
        )
    }

    if 'child_modules' in ($module|columns) {
        for submodule in $module.child_modules {
            $resources ++= (get-resources $submodule)
        }
    }

    return $resources
}

# Check if all fields necessary to import a resource are present in the state by comparing the field types of the resource and its resource_map entry
def is-mergeable [
    $resource: record<resource_type: string, address: string, values: record>
] record -> boolean {
    (get-resource-types $resource | merge ($resources_map | get $resource.resource_type | get fields)) == (get-resource-types $resource)
}


# This is where actual teraform import happens
# Import command is generated by running a closure from the resources map appropriate for the resource type
def import-resource [
    resource: record<resource_type: string, address: string, values: record>
] record -> record<success: bool, message: string> {

    mut result = {
        success: false,
        message: ""
    }

    if (is-mergeable $resource) {
        let identifier = (do ($resources_map | get $resource.resource_type | get identifier) $resource)

        std log info $"Attempting to import resource ($resource.address) using identifier ($identifier)"

        let import_result = (
            do { ^terraform import $resource.address $identifier -no-color}
            | complete
        )

        if $import_result.exit_code == 0 {
            $result.success = true
            $result.message = $"Resource ($resource.address) successfully imported"
        } else if $import_result.exit_code == 1 and 'Resource already managed by Terraform' in $import_result.stderr {
            $result.message = $"Resource ($resource.address) already managed by Terraform"
        } else {
            $result.message = $"Error when importing resource ($resource.address)(char nl)($import_result.stderr)"
        }

    } else {
        let required_fields = (
            $resources_map
            | get $resource.resource_type
            | get fields
            | columns
            | str join ' '
        )
        $result.message = $"Unable to import resource ($resource.address). Necessary data not present in Terraform state. Required fields are: ($required_fields)"
    }

    return $result
}

def display-result-message [
    result: record<success: bool, message: string>
] record<success: bool, message: string> -> nothing {
    if $result.success {
        std log info $result.message
    } else {
        std log error $result.message
    }
}

def generate-state-file [
    state_file: string
] {

    std log info "State file does not exist. Generating..."

    terraform plan -out tfplan
    | ignore

    terraform show -json tfplan
    | save -f $state_file

    rm tfplan

    std log info "State file successfully generated"
}

def remove-state-file [
    state_file: string
] {
    std log info "Removing state file"

    rm $state_file
}

def get-existing-resources [] nothing -> list<string> {
    ^terraform state list
    | lines
    | where not $it starts-with data
}

# Returns number of imported resources, will be retried if higher than 0
export def run-import-pass [
    state_file: string
] string -> int {
    generate-state-file $state_file

    let root_module = (
        open $state_file
        | get planned_values.root_module
    )

    let existing_resources = (get-existing-resources)

    let resources = (
        get-resources $root_module
        | where resource_type in ($resources_map|columns) and address not-in $existing_resources
    )

    mut counter = 0

    for resource in $resources {
        let import_result = (import-resource $resource)

        display-result-message $import_result

        if $import_result.success {
            $counter += 1
        }
    }

    remove-state-file $state_file

    return $counter
}

def main [] {
    let state_file = $"(random chars -l 10).json"

    while (run-import-pass $state_file) > 0 {
        std log info "Resources were imported into the state, rerunning the process"
    }

    std log info "No more resources available for import"

}
